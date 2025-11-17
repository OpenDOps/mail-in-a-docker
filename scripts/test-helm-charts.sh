#!/bin/bash
# Helm chart template testing script
# Tests Helm charts with values files from helmtest/ folder
# Usage: ./scripts/test-helm-charts.sh

set -euo pipefail

for chart in helm/*/Chart.yaml; do
  if [ -f "$chart" ]; then
    chart_dir="$(dirname "$chart")"
    chart_name="$(basename "$chart_dir")"
    helmtest_dir="helmtest"
    mkdir -p "$helmtest_dir/results"
    echo "Testing chart: $chart_dir"

    # Find test values files in project root helmtest folder (direct children only, not subdirectories)
    test_files=$(find "$helmtest_dir" -maxdepth 1 -name "${chart_name}-values*.yaml" -type f 2>/dev/null | sort)

    if [ -n "$test_files" ]; then
      # Test with each values file
      for test_file in $test_files; do
        file_name=$(basename "$test_file" .yaml)
        result_file="$helmtest_dir/results/${file_name}-result.yaml"
        echo "  Testing with: $test_file"

        if helm template helm-test "$chart_dir" --values "$test_file" > "$result_file" 2>&1; then
          echo "    ✓ Success: $result_file"
        else
          echo "    ✗ ERROR: Failed to render with $test_file"
          cat "$result_file" | head -50
          exit 1
        fi
      done
    else
      # Use default values.yaml if no test files found
      echo "  No test files found, using default values.yaml"
      result_file="$helmtest_dir/results/${chart_name}-values-result.yaml"

      if helm template helm-test "$chart_dir" > "$result_file" 2>&1; then
        echo "    ✓ Success: $result_file"
      else
        echo "    ✗ ERROR: Failed to render with default values"
        cat "$result_file" | head -50
        exit 1
      fi
    fi
  fi
done
