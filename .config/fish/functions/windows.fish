function windows
    set num (efibootmgr | grep -i "Windows Boot Manager" | head -1 | sed -E 's/^Boot([0-9A-Fa-f]{4}).*/\1/')
    
    if test -z "$num"
        echo "Entrée 'Windows Boot Manager' introuvable (Windows est-il installé ?)"
        return 1
    end
    
    sudo efibootmgr -n $num >/dev/null; and systemctl reboot
end
