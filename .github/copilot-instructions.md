General guidance:
- Focus on just requested change. 
- Make as minimal changes as possible. 
- If you see things that would be nice to implement, suggest them to me. Dont just make the changes. 
- Ask questions if anything is unclear. 

Powershell guidance:
- Avoid having multiple consecutive lines of Write-Host. Instead combine them into one Write-host statement. 

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

Ask questions if anything is unclear. 