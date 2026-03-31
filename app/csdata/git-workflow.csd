title    "Git Workflow -- Cheat Sheet"
subtitle "commit, tag, push, branch, stash -- Release-Workflow"
sections {
    {title "daily workflow" type table content {
        {status      {git status}                            1}
        {diff        {git diff}                              1}
        {{diff staged} {git diff --cached}                   1}
        {add         {git add -A  ;# all changes}           1}
        {{add patch} {git add -p  ;# interactive}           1}
        {commit      {git commit -m "message"}               1}
        {{amend}     {git commit --amend --no-edit}          1}
        {log         {git log --oneline -10}                 1}
    }}
    {title "release workflow" type code content {
        {# 1. Develop + test}
        {tclsh tests/all.tcl}
        {}
        {# 2. Version bump}
        {tclsh tools/bump.tcl}
        {}
        {# 3. Build}
        {make}
        {}
        {# 4. Commit + tag}
        {git add -A}
        {git commit -m "0.9.4.25: ISO B/C paper, write -chan"}
        {git tag -a v0.9.4.25 -m "0.9.4.25"}
        {}
        {# 5. Push}
        {git push origin master --tags}
    }}
    {title "branch" type table content {
        {create      {git checkout -b feature-x}             1}
        {switch      {git checkout main}                     1}
        {list        {git branch -a}                         1}
        {merge       {git merge feature-x}                   1}
        {delete      {git branch -d feature-x}               1}
        {rebase      {git rebase main}                       1}
    }}
    {title "stash" type table content {
        {save        {git stash  ;# push WIP}                1}
        {{save msg}  {git stash push -m "wip: canvas fix"}   1}
        {list        {git stash list}                        1}
        {pop         {git stash pop  ;# apply + drop}        1}
        {apply       {git stash apply stash@{1}}             1}
        {drop        {git stash drop stash@{0}}              1}
    }}
    {title "tag" type table content {
        {list        {git tag}                               1}
        {annotated   {git tag -a v1.0 -m "Release 1.0"}     1}
        {lightweight {git tag v1.0}                          1}
        {{push tags}  {git push origin --tags}  1}
        {delete      {git tag -d v1.0}                      1}
        {show        {git show v1.0}                         1}
    }}
    {title "remote" type table content {
        {list        {git remote -v}                         1}
        {add         {git remote add origin url}             1}
        {fetch       {git fetch origin}                      1}
        {pull        {git pull origin main}                  1}
        {push        {git push origin main}                  1}
        {{push -u}   {git push -u origin main  ;# set upstream} 1}
        {{push force}  {git push --force-with-lease}  1}
    }}
    {title "undo" type table content {
        {unstage     {git restore --staged file.tcl}         1}
        {discard     {git restore file.tcl}                  1}
        {{reset soft}  {git reset --soft HEAD~1  ;# keep changes}  1}
        {{reset hard}  {git reset --hard HEAD~1  ;# lose changes}  1}
        {revert      {git revert HEAD  ;# new commit undoing}   1}
        {reflog      {git reflog  ;# recover lost commits}      1}
    }}
    {title "gitignore patterns" type table content {
        {{build out}  {out/  *.pdf  *.log}  0}
        {privat      {nogit/}                                0}
        {backups     {*.bak  *~}                             0}
        {OS          {.DS_Store  Thumbs.db}                  0}
        {negation    {!important.pdf  ;# keep this file}     0}
        {check       {git check-ignore -v filename}          1}
    }}
}
