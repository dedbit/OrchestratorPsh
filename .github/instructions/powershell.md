# PowerShell Instructions

- Avoid having multiple consecutive lines of Write-Host; combine them into one statement.
- Use early return statements for validation checks.
- Avoid nested if statements; check conditions and exit immediately if not met.
- Keep the code structure simple and flat.
- Create generic test functions instead of complex validation logic (e.g., Assert-StringNotEmpty).
- Try to keep the size of any function at less than 50 lines.
- Put variables at the top of functions or scripts.
- Add simple and short function summary for functions, with sample values for parameters.
