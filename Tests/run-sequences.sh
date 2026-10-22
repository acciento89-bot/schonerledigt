#!/bin/sh
set -eu
sequence_test_dir=$(mktemp -d /tmp/schon-sequences.XXXXXX)
trap 'rm -f "$sequence_test_dir/main.swift" "$sequence_test_dir/tests"; rmdir "$sequence_test_dir"' EXIT
if [ -f SchonErledigt/Domain/HouseholdSequence.swift ]; then cat SchonErledigt/Domain/HouseholdSequence.swift > "$sequence_test_dir/main.swift"; else : > "$sequence_test_dir/main.swift"; fi
cat SchonErledigt/Domain/RoutineItem.swift >> "$sequence_test_dir/main.swift"
if [ -f SchonErledigt/Domain/SequenceCardAdapter.swift ]; then cat SchonErledigt/Domain/SequenceCardAdapter.swift >> "$sequence_test_dir/main.swift"; fi
cat Tests/main.swift >> "$sequence_test_dir/main.swift"
swiftc "$sequence_test_dir/main.swift" -o "$sequence_test_dir/tests"
"$sequence_test_dir/tests"
