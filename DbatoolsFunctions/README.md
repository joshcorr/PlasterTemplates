Using Plaster to get started
--------------

In order to speed up developing cmdlets I had the idea of using a plaster template included in this repo.

`Install-Module Plaster`
`Invoke-Plaster -TemplatePath C:\code\DbatoolsFunctions\ -DestinationPath C:\code\dbatools\`
Answer the Questions, or hit enter for the defaults
```
The action this cmdlet will take (Verb without dash): Test
The element this cmdlet will interact with (Noun without dba or dash): Something
Who is authoring this function (Git Name):
What is your Twitter Handle (without @): psdbatools
If your creating a function, where will this be used:
[E] External  [I] Internal  [?] Help (default is "E"): E
```