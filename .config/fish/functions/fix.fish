function fix
     echo 'WINEDLLOVERRIDES="winmm=n,b;steam_api64=n,b;OnlineFix64=n,b" %command%' | wl-copy; echo "Texte copié dans le presse-papier !"; 
end
