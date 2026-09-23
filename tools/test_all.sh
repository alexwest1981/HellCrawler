#!/usr/bin/env bash
# Complete test — one command, one summary, and ALWAYS an answer.
#
# Alex, 23 Sep: "Skapa ett script för att köra komplett test på allt, så du slipper slösa tokens på
# det" and then "tvinga fram ett svar ... timeout ... presentera vad den fann inom det loppet ...
# och kanske någon form av fallback". So the rule of this script is: it never waits forever, and it
# never ends without saying what it knows. Every layer has its own clock; a layer that runs out of
# time reports what it produced in the time it had, and the layers that did not run are named.
#
# Layers:
#   1. the generated data  — every tools/gen_*.py --check (art, sound, i18n files, tiles, stages)
#   2. data drift          — run the stage generator against a copy; are the committed stages still
#                            what it produces?
#   3. the Godot suite     — tools/test.sh, the same gate as always, with its own clock
#
# Fallbacks, in order:
#   * a layer that times out  -> the last lines it wrote are printed; the rest are named as not run
#   * the suite's own total is missing -> the total is summed from the per-test lines that exist
#   * tests the suite never reached, or reached and got no verdict from -> run one by one, directly
#   * a test that hangs -> its raw output is kept, and its LAST LINE is printed (that is where it
#     stopped; this is what took nine minutes to find by hand once)
#
# The summary flags a test as NO REPORT, never OK, when it prints no control count. A test that
# dies on a parse error prints nothing, so "0 kontroller, 0 fel" reads green while nothing ran.
# That happened twice on 23 Sep, once from a shell variable with a Swedish letter in it.
#
# Usage: tools/test_all.sh [--keep]     --keep skips the Godot import step
# Log:   /tmp/hellcrawler_test_all.log  (override with LOG=/path)

set -u
cd "$(dirname "$0")/.." || exit 2

LOG=${LOG:-/tmp/hellcrawler_test_all.log}
RAW_DIR="${LOG%.log}.d"
KEEP_IMPORT=0
[ "${1:-}" = "--keep" ] && KEEP_IMPORT=1

TOOLS_LIMIT=${TOOLS_LIMIT:-300}
SUITE_LIMIT=${SUITE_LIMIT:-1800}
TEST_LIMIT=${TEST_LIMIT:-120}

: > "$LOG"
rm -rf "$RAW_DIR"; mkdir -p "$RAW_DIR"

say() { printf '%s\n' "$*" | tee -a "$LOG"; }

# One clock per layer. A layer that runs out of time is not a failure of the code, and it is not
# silence either: the last lines it wrote are shown, because that is what it found before the clock
# ran out. Exit 124 is the shell's own "killed by timeout"; 128+ means an outside signal, which is
# how a run stopped by hand reads. Calling that "FEL tools/test.sh" would blame the suite for
# something the person at the keyboard did.
LAYER_TIMEOUT=0
run_layer() {                       # run_layer NAME LIMIT CMD...
    local name=$1 limit=$2; shift 2
    local start=$SECONDS
    timeout "$limit" "$@" >>"$LOG" 2>&1
    local code=$?
    local took=$((SECONDS - start))
    if [ $code -eq 0 ]; then
        say "  ok        $name  (${took}s)"
    elif [ $code -eq 124 ]; then
        LAYER_TIMEOUT=1
        say "  TIMEOUT   $name  (${limit}s slut) — sista raderna:"
        tail -3 "$LOG" | sed 's/^/              /' | tee -a "$LOG"
    elif [ $code -ge 128 ]; then
        LAYER_TIMEOUT=1
        say "  AVBRUTEN  $name  (signal $((code - 128)), ${took}s) — stoppad utifrån, inte av sig själv"
    else
        say "  FEL       $name  (exit $code, ${took}s) — sista raderna:"
        tail -3 "$LOG" | sed 's/^/              /' | tee -a "$LOG"
    fi
    return $code
}

# ---------------------------------------------------------------- 1. generated data
say "== generated data =="
TOOLS_FAIL=0
for gen in tools/gen_*.py; do
    grep -qE -- '--check|--kontroll' "$gen" 2>/dev/null || continue
    name=$(basename "$gen")
    if timeout "$TOOLS_LIMIT" python3 "$gen" --check >>"$LOG" 2>&1; then
        say "  ok        $name"
    else
        say "  FEL       $name  ($(tail -2 "$LOG" | tr '\n' ' '))"
        TOOLS_FAIL=$((TOOLS_FAIL + 1))
    fi
done

# ---------------------------------------------------------------- 2. data drift
say "== data drift =="
DRIFT=0
if [ -d game/data/stages ]; then
    BEFORE=$(cat game/data/stages/*.json 2>/dev/null | sha256sum | cut -c1-16)
    cp -r game/data/stages "$RAW_DIR/stages_before"
    if run_layer "gen_stages.py" "$TOOLS_LIMIT" python3 tools/gen_stages.py; then
        AFTER=$(cat game/data/stages/*.json 2>/dev/null | sha256sum | cut -c1-16)
        if [ "$BEFORE" != "$AFTER" ]; then
            say "  FEL       stage_01..90 skiljer sig från generatorn ($BEFORE -> $AFTER)"
            DRIFT=1
        else
            say "  ok        stage_01..90 är vad generatorn ger"
        fi
    else
        say "  FEL       gen_stages.py kunde inte köras"
        DRIFT=1
    fi
    # Put the real files back no matter how it went: the committed stages are the truth until a
    # human says otherwise, and a wrong generator must not be able to eat them.
    rm -rf game/data/stages && cp -r "$RAW_DIR/stages_before" game/data/stages
fi

# ---------------------------------------------------------------- 3. the Godot suite
say "== the Godot suite =="
export DISPLAY=${DISPLAY:-:99}
if [ $KEEP_IMPORT -eq 0 ]; then
    run_layer "godot --import" 300 godot --headless --path game --import
fi
run_layer "tools/test.sh" "$SUITE_LIMIT" bash tools/test.sh

# ---------------------------------------------------------------- what the suite managed
# Every test file the suite announced, and whether it ever gave a verdict. A test inside a loop
# that was killed mid-way has a header and no count — that is the "no report" case, and it is the
# one that looks green when read as a total.
declare -A REACHED=() REPORTED=() FAILED=()
ORDER=()
while IFS=$'\t' read -r kind name; do
    [ -z "${name:-}" ] && continue
    [ -z "${REACHED[$name]:-}" ] && ORDER+=("$name")
    REACHED[$name]=1
    case "$kind" in
        report) REPORTED[$name]=1 ;;
        fel)    FAILED[$name]=1; REPORTED[$name]=1 ;;
    esac
done < <(awk '
    /^=== tests\// { print "head\t" $2; last = $2; next }
    /^  ##FEL##/   { print "fel\t" $2; next }
    /kontroller[,:]|kontroller: / { print "report\t" last }
' "$LOG" | sed 's/\t$//')

# The suite prints its own total. If it was killed before that line, sum what exists: the number is
# then a floor, not the whole, and it is reported as such.
TOTAL=$(grep -oE 'TOTALT: [0-9]+ kontroller, [0-9]+ fel' "$LOG" | tail -1)
FLOOR=0
if [ -z "$TOTAL" ]; then
    read -r c f < <(awk '/kontroller,/ {
        for (i = 1; i <= NF; i++) if ($i == "kontroller,") c += $(i-1)
        for (i = 1; i <= NF; i++) if ($i == "fel") f += $(i-1)
    } END { print c+0, f+0 }' "$LOG")
    TOTAL="minst $c kontroller, $f fel (sviten hann inte skriva sin egen rad)"
    FLOOR=1
fi

# ---------------------------------------------------------------- the ones without a verdict
# Fallback: run the tests the suite did not get a verdict from, one at a time, each with its own
# clock. This is what turns "the suite was killed at 420 seconds" into "this test hangs, and here
# is its last line".
MISSING=()
if [ ${#ORDER[@]} -gt 0 ]; then
    for t in "${ORDER[@]}"; do
        [ -z "${REPORTED[$t]:-}" ] && MISSING+=("$t")
    done
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    say ""
    say "== ${#MISSING[@]} test(s) utan dom — körs en och en, egen klocka =="
    for t in "${MISSING[@]}"; do
        limit=$TEST_LIMIT
        out="$RAW_DIR/$(basename "$t" .gd).log"
        start=$SECONDS
        timeout -k 5 "$limit" godot --headless --path game --script "res://$t" >"$out" 2>&1
        code=$?
        took=$((SECONDS - start))
        # Provens summa skrivs i två format: "N kontroller, M fel" och "kontroller: N, fel: M".
        # test_fiendeeditor använder det andra, och en dom-läsare som bara kan det första ser ett
        # prov som passerar som ett prov utan svar.
        count=$(grep -oE '[0-9]+ kontroller, [0-9]+ fel|kontroller: *[0-9]+, *fel: *[0-9]+' "$out" | tail -1)
        case $code in
            0)   verdict="ok        ($count)" ;;
            124) verdict="HÄNGER    (${limit}s, exit 124)" ;;
            *)   verdict="FEL       (exit $code)" ;;
        esac
        say "  $t"
        say "      $verdict   ${took}s"
        # The last line of a PASSING test is usually a Godot leak warning, which says nothing. It is
        # only worth printing when the test did not pass — then it is where the test stopped.
        case "$verdict" in
            ok*) ;;
            *) say "      sista raden: $(tail -1 "$out" | cut -c1-160)" ;;
        esac
        say "      raw: $out"
        [ -n "$count" ] && REPORTED[$t]=1 || FAILED[$t]=1
    done
fi

# ---------------------------------------------------------------- the answer
STILL=0
for t in "${ORDER[@]:-}"; do
    [ -z "${REPORTED[$t]:-}" ] && STILL=$((STILL + 1))
done
# Bara provens EGNA fel räknas här ("  ##FEL## tests/x.gd: exit N"). Raden ovan räknade varje rad som
# började med "  FEL" — vilket också är lagrets egna rader ("FEL tools/test.sh"), så en enda röd
# körning kunde stå som två, och numret sade ingenting om hur många prov som faktiskt föll.
FEL=$(grep -c '^  ##FEL##' "$LOG")
PROBLEMS=$((FEL + TOOLS_FAIL + DRIFT + STILL))

say ""
if [ $PROBLEMS -eq 0 ]; then
    say "RESULT: GRÖNT — $TOTAL"
else
    say "RESULT: RÖTT — $TOTAL"
    [ "$FEL" -gt 0 ] && say "        $FEL test(s) med fel: $(for t in "${ORDER[@]:-}"; do [ -n "${FAILED[$t]:-}" ] && printf '%s ' "$(basename "$t")"; done)"
    [ $STILL -gt 0 ] && say "        $STILL test(s) svarade inte ens enskilt"
    [ $TOOLS_FAIL -gt 0 ] && say "        $TOOLS_FAIL generator-kontroll(er) föll"
    [ $DRIFT -gt 0 ] && say "        banorna skiljer sig från generatorn"
    [ $LAYER_TIMEOUT -gt 0 ] && say "        minst ett lager tog slut på tid eller avbröts — det som hanns med står ovan"
fi
say "        log: $LOG"

[ $PROBLEMS -eq 0 ] && exit 0
exit 1
