#!/bin/zsh

project_dir="${0:A:h}"
app_dir="$project_dir/dist/Plates Kitchen.app"

if [[ ! -t 0 || ! -t 1 ]]; then
    print -u2 "Run start.sh in a terminal."
    exit 1
fi

while true; do
    clear
    print "Plates Kitchen"
    print
    print "  b  Build"
    print "  r  Run"
    print "  q  Quit"
    print
    read -rsk 1 key
    print

    case "$key" in
        b)
            if "$project_dir/Scripts/build-app.sh"; then
                print "Build complete."
            else
                print "Build failed."
            fi
            ;;
        r)
            if [[ -d "$app_dir" ]]; then
                if ! open "$app_dir"; then
                    print "Could not open the app."
                fi
            else
                print "Build the app first (b)."
            fi
            ;;
        q) exit 0 ;;
        *) continue ;;
    esac

    print "Press any key to return to the menu."
    read -rsk 1 key
done
