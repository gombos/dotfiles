#!/bin/bash
#user=LaszloGombos repo=dracut;
user=dracutdevs-extra repo=dracut-canary;
#user=gombos repo=dotfiles
#user=initramfs-modules repo=initramfs-modules;
gh api repos/$user/$repo/actions/runs --paginate -q '.workflow_runs[] | "\(.id)"' | xargs -n1 -I % gh api repos/$user/$repo/actions/runs/% -X DELETE
