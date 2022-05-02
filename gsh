#!/bin/bash


runner="self-hosted"

history -r ~/.gsh_history

cd "$( dirname "$(readlink -e "$0")")"

# Prints to stdout
#
#     <status>\t<id>\t<duration>\t<time ago>\n
#
workflow_status() {
        # 'gh run list' output looks like this
        #
        # queued          Update ghsh     cmd main    workflow_dispatch       10940   0s      0m
        # completed       success Update gsh     cmd main    workflow_dispatch       10930   17s     3m
        # completed       success Update gsh     cmd main    workflow_dispatch       10929   15s     3m
        # completed       success Update gsh     cmd main    workflow_dispatch       10927   18s     3m
        # [...]
        #
        # So different field numbers but still tab separated...
        gh run list --workflow=cmd.yml | sed "s/\t.*workflow_dispatch//" | head -1
}

lastid=0
BLUE=$'\001\e[00;34;1;4m\002'
GREEN=$'\001\e[00;32;1m\002'
NOC=$'\001\e[0m\002'
while true; do
        read -p "${BLUE}ghshell${NOC}(${GREEN}${runner}${NOC}) " -e cmd
        history -s "$cmd"

        case "$cmd" in
                exit)
                        break
                        ;;
                runner*)
                        read -r x runner <<<$cmd
                        echo "Runner set to '$runner'."
                        ;;
                *)
                        if [[ "$cmd" =~ ^[[:space:]]*$ ]]; then
                                continue
                        fi

                        gh workflow run cmd.yml -f "cmd=$cmd" -f "runner=$runner" >/dev/null
                        IFS=$'\t' read status id rest <<<"$(workflow_status)"
                        if [ "$id" != "" -o "$id" = "$lastid" ]; then
                                printf "%s" "Waiting for run $id ..."
                                while true; do
                                        IFS=$'\t' read status id rest <<<"$(workflow_status)"
                                        if [[ $status =~ (completed|cancelled|failed) ]]; then
                                                printf "\n\n"
                                                break
                                        fi
                                        printf "."
                                        sleep 1
                                done
                                
                                # gh workflow run prints stuff like
                                #
                                # exec    Set up job      2022-04-26T19:00:20.0914880Z Current runner version: '2.286.1'
                                # exec    Set up job      2022-04-26T19:00:20.0922641Z Runner name: 'my-runner-294f85cc485'
                                # exec    Set up job      2022-04-26T19:00:20.0923259Z Runner group name: 'Default'
                                # exec    Set up job      2022-04-26T19:00:20.0923929Z Machine name: '294f85cc485'
                                # exec    Set up job      2022-04-26T19:00:20.0926419Z ##[group]GITHUB_TOKEN Permissions
                                # exec    Set up job      2022-04-26T19:00:20.0927258Z Actions: write
                                # [...]
                                # exec    Set up job      2022-04-26T19:00:20.0930966Z SecurityEvents: write
                                # exec    Set up job      2022-04-26T19:00:20.0931299Z Statuses: write
                                # exec    Set up job      2022-04-26T19:00:20.0931643Z ##[endgroup]
                                # exec    Set up job      2022-04-26T19:00:20.0935092Z Secret source: Actions                                        # exec    Set up job      2022-04-26T19:00:20.0935688Z Prepare workflow directory
                                # exec    Set up job      2022-04-26T19:00:20.1680181Z Prepare all required actions
                                # exec    sh      2022-04-26T19:00:20.2912375Z ##[group]Run ls ..
                                # exec    sh      2022-04-26T19:00:20.2912855Z ls ..
                                # exec    sh      2022-04-26T19:00:20.2943292Z shell: /usr/bin/bash -e {0}
                                # exec    sh      2022-04-26T19:00:20.2943721Z ##[endgroup]
                                # exec    sh      2022-04-26T19:00:20.3340937Z gsh        <---- actual payload we want
                                # exec    Complete job    2022-04-26T19:00:20.3524582Z Cleaning up orphan processes
                                gh run view "$id" --log 2>&1 | \
                                egrep -v "(Set up job|Complete job)" |\
                                sed "/##\[group\]/,/##\[endgroup\]/d" |\
                                sed "s/^exec\tsh\t[0-9TZ.:-]*[[:space:]]//"

                                history -s "$cmd"

                                lastid=$id
                        else
                                echo "ERROR: workflow execution did not happen! Please check Github action GUI!"
                        fi
                fi
                ;;
        esac
done

history -w ~/.gsh_history
