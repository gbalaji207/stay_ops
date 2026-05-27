Stage all changes, write a concise conventional commit message based on
the diff, commit, and push to the current branch.

Steps:
1. `git add .`
2. Review the staged diff to craft a commit message following conventional
   commits format (feat:, fix:, chore:, etc.)
3. `git commit -m "<generated message>"`
4. `git push`

Report the branch, commit hash, and the commit message used.