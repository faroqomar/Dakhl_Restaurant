#!/bin/sh
set -eu
helper=/Users/eros/.codex/skills/penpot/scripts/penpot-client.mjs
node "$helper" export 812c55ce-996a-805c-8008-dcf1263a146e outputs/penpot/phase01/native-exports/desktop-sales-wireframe.png --scale 2
node "$helper" export 812c55ce-996a-805c-8008-dcf1d06dbde5 outputs/penpot/phase01/native-exports/component-states-design.png --scale 2
node "$helper" export 812c55ce-996a-805c-8008-dcf1d6c3dfdf outputs/penpot/phase01/native-exports/component-states-wireframe.png --scale 2
node "$helper" export 812c55ce-996a-805c-8008-dcf2225706d4 outputs/penpot/phase01/native-exports/phone-invoice-adaptation-design.png --scale 2
node "$helper" export 812c55ce-996a-805c-8008-dcf22540a496 outputs/penpot/phase01/native-exports/phone-invoice-adaptation-wireframe.png --scale 2
node "$helper" export 812c55ce-996a-805c-8008-dcf2288ed2eb outputs/penpot/phase01/native-exports/large-text-320-design.png --scale 2
node "$helper" export 812c55ce-996a-805c-8008-dcf22acd25e2 outputs/penpot/phase01/native-exports/large-text-320-wireframe.png --scale 2
