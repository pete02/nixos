 pulled=1
 flaked=1
 
 if [ "$pulled" -eq 1 ] || [ "$flaked" -eq 1 ]; then
    msg="System ready for rebuild:"
    if [ "$pulled" -eq 1 ]; then
        msg="$msg \n- configuration pulled"
    fi
    if [ "$flaked" -eq 1 ]; then
        msg="$msg \n- flake updated"
    fi
    notify-send "NixOS" "$msg"
fi