General guidance:
- Focus on just requested change. 
- Continue to run tests and make changes iteratively until problem is solved. 
- Make as minimal changes as possible. 
- Before starting work on a change, ask questions if anything is unclear. But once work is started, assume approval on all changes. 

Powershell guidance:
- Avoid having multiple consecutive lines of Write-Host. Instead combine them into one Write-host statement. 
- Use early return statements for validation checks.
- Avoid nested if statements; check conditions and exit immediately if not met.
- Keep the code structure simple and flat.
- Create generic test functions instead of complex validation logic. E.g. Assert-StringNotEmpty that checks that value is not null, is a string, is not empty and throws an exception. 
- Try to keep the size of any function at less than 50 lines. 
- Put variables in the top of functions or scripts. 
- Add simple and short function summary for functions, with sample values for parameters
*   When constructing paths in PowerShell scripts, prefer the following pattern for robustness in both direct script execution and interactive terminal sessions:
    ```powershell
    $variablePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'relative\path\to\resource'
    ```
- Carefully validate path references, especially when using relative paths. 

Powershell testing guidance:
- Follow the test guidance at [copilot-instructions-test.md](copilot-instructions.test.md).
- Separate production code from test code. Functions for testing modules should be placed separate scripts or modules. 
- Integration tests should use the production modules. 
- All tests should be referenced in the root TestAllAzureUser.ps1 or TestAllCert.ps1 scripts, depending on the used authentication method. 


Readme.md file should contain following information:
- Only include elements that are clearly included in the repository or requested directly in prompt. 
- How to install required packages used for developemnt as a one-liner winget command. 
- How to start debugging
- List of relevant configuration files. 
- Architecture overview containing a list of components used and a one sentence description for each. 
- If Architecture.md exists add reference to this. 

Architecture.md should contain a concise architecture overview in Markdown for the current repository. Only include elements that are clearly included in the repository. Include these sections with each description limited to one sentence:
- **Project Overview**: Brief summary.
- **System Architecture**: High-level description with a Mermaid diagram.
- **Technology Stack**: List of technologies in bullet point form.
- **Modules and Components**: Breakdown of key modules, components, and their responsibilities.
- **Connections & Accesses**: List of all connections with type (like app credentials or api key) and a short description.
- **Data Stores & Configurations**: List data stores and configuration areas with one sentence description on each.
- **Data Flow**: Summary in one sentence.
- **Security Considerations**: Key practices in one sentence.



