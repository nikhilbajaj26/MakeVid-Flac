#!/bin/bash
shopt -s nullglob
shopt -s dotglob
#Requires ffmpeg 4+, also imagemagick now I guess. All fine on mac sierra.

#Naming fxn
namer () {
  if [[ -e $1 ]]; then
    count=1
    while [[ -e "${1%.*} ${count}.${1##*.}" ]]; do
      (( count++ ))
    done
    endname="${1%.*} ${count}.${1##*.}"
  else
    endname="$1"
  fi
}

table () {
  y='-' # wc -L is GNUism and not work on mac. The rest ok.
  words=( "$1" "${table_list[@]}" ); length=0
  for d in "${words[@]}"; do
    (( ${#d} > length )) && length=${#d}
  done
  div=$y$y; ldiv=2 #Mininum padding on either side
  header=$(printf "$1" | wc -m)
  while (( (header+(2*ldiv)) < length )); do
    div+=$y
    (( ldiv++ ))
  done
  printf "%s%s%s\n" $div "$1" $div
  printf "%s\n" "${table_list[@]}"
  for (( c=0; c<$(( header+(2*ldiv) )); c++ )); do
    printf $y
  done
  printf "\n"
  unset table_list
}

namer "todo.txt"
todo="$PWD/$endname"
namer "prefs.txt"
prefs="$PWD/$endname"
namer "temp.txt"
temp="$PWD/$endname"
namer "tlist.txt"
tlist="$PWD/$endname"
namer "titles.txt"
titles="$PWD/$endname"

echo "Select mode"
select global in "Interactive" "Quiet"; do [[ $global ]] && break; done

for i in */; do
  clear #cleanliness is good
  (
    cd "$i"
    title="${i%/}"
    table_list=( "$title" )
    table "TITLE"
    [[ ! $(echo *.flac) ]] && printf "\nNo audio." && { read -t 1 -n 1 -s -r; exit; }
    [[ ! $(echo *.{png,jpg,jpeg}) ]] && printf "\nNo images." && { read -t 1 -n 1 -s -r; exit; }
    if [[ $global =~ ^I ]]; then
      #edit title.
      edit=0
      if ! grep -qs '^i' "$prefs"; then #q=quiet,s=noerrors
        printf "\n"
        while true; do
          read -p "Edit title? Type 'd' to permanently hide this prompt. (y/n/d)" ynd
          case "$ynd" in
            [Yy] ) edit=1; break;;
            [Nn] ) break;;
            [Dd] ) echo "i" >> "$prefs"; break;;
            * ) echo "Please answer y/Y, n/N, or d/D.";;
          esac
        done
      fi

      if (( edit==1 )); then
        echo "Enter new title:"; read title
        clear
        table_list=( "$title" )
        table "TITLE"
      fi

      #Image
      for j in *.{png,jpg,jpeg}; do
        for k in {w,h}; do eval "$k=\$(identify -format \"%${k}\" \"$j\")"; done
        list+=( "${j} (${w}x${h})" )
      done
      img=''
      case ${#list[@]} in
        1) img="${list[0]}"
          ;;
        *) printf "\nSelect image\n"
          select img in "${list[@]}"; do
            [[ "$img" ]] && break
          done
          ;;
      esac
      table_list=( "$img" )
      printf "\n"
      table "IMAGE"
      newline=0
      name="${img% (*)}"; dim="${img##* (}"; dim="${dim%)}"; w="${dim%x*}"; h="${dim#*x}"

      #Saving image prefs...no word splitting in double brackets.
      s=$(grep -s '^s' "$prefs"); res=${s#s}
      if [[ ! $s ]]; then
        printf "\n" && newline=1
        read -p "Resize? (y/n)" ans
        if [[ $ans =~ ^[Yy]$ ]]; then
          select opt in "720p" "1080p" "Custom"; do
            if [[ $opt =~ C ]]; then
              while [[ ! $res =~ ^[1-9][0-9]*$ ]]; do
                read -p "Enter custom resolution: " res
                res="$(echo "$res" | sed -E 's/^0+//')"
              done
              break
            elif [[ $opt ]]; then
              res="${opt%p}"
              break
            fi
          done
        fi
        read -p "Apply to all images? (y/n)" ans
        [[ $ans =~ ^[Yy]$ ]] && echo "s${res}" >> "$prefs"
      fi

      #If no resize select, or prefs is existing but blank, res is null.
      if [[ $res ]]; then
        (( w>h )) && c='^' || c=''
        namer "${name%.*}.png" #Sets endname to non-taken filename
        (( newline==0 )) && printf "\n" && newline=1
        printf "Resizing to ${res}p..."
        convert "$name" -resize ${res}x${res}$c "$endname"
        for k in {w,h}; do eval "$k=\$(identify -format \"%${k}\" \"$endname\")"; done
        printf "Done!\n"; echo "Resized image: $name (${w}x${h})"
      else
        namer "$name"
        cp "$name" "$endname"
      fi

    else
      for j in *.{png,jpg,jpeg}; do name="$j"; break; done
      namer "$name"
      cp "$name" "$endname"
      for k in {w,h}; do eval "$k=\$(identify -format \"%${k}\" \"$endname\")"; done
    fi

    if [[ $(( w%2 )) -ne 0 || $(( h%2 )) -ne 0 ]]; then
      if [[ $global =~ ^I ]]; then
        (( newline==0 )) && printf "\n" && newline=1
        printf "Bad dimensions, shaving..."
      fi
      w=$(( w-(w%2) )); h=$(( h-(h%2) ))
      convert "$endname" -crop ${w}x${h}+0+0 "$endname"
      [[ $global =~ ^I ]] && printf "Done!\n" && echo "Shaved image: $name (${w}x${h})"
    fi

    #Audio
    if [[ $global =~ ^I ]]; then
      for k in *.flac; do table_list+=( "$k" ); done
      flac_list=( "${table_list[@]}" )
      printf "\n"
      table "AUDIO" #or fnum
      printf "\n"
      edit=0
      if ! grep -qs '^r' "$prefs"; then
        while true; do
          read -p "Edit tracklist? Type 'd' to permanently hide this prompt. (y/n/d)" ynd
          case "$ynd" in
            [Yy] ) edit=1; break;;
            [Nn] ) printf "\n"; break;;
            [Dd] ) echo "r" >> "$prefs"; printf "\n"; break;;
            * ) echo "Please answer y/Y, n/N, or d/D.";;
          esac
        done
      fi

      if (( edit==1 )); then
        track=''; len=${#flac_list[@]}; unset flac_list
        while [[ ! $track = Exit ]]; do
          clear
          table_list=( "${flac_list[@]}" )
          table "AUDIO"
          printf "\n"
          echo "Add tracks to list. Press $((len+1)) to reset, $((len+2)) to exit."
          select track in *.flac Reset Exit; do
            case "$track" in
              Reset ) unset flac_list; break;;
              Exit ) [[ ${#flac_list[@]} -eq "0" ]] && printf "\nError: must select at least one track to continue." && { read -t 1 -n 1 -s -r; track=''; } || printf "\n"
              break;;
              * ) [[ $track ]] && flac_list+=( "$track" ) && break;;
            esac
          done
        done
      fi

      #store vars. image is image, endname is tracks file now.
      image="$endname"
      namer "tracks.txt"
      printf "%s\n" "${flac_list[@]}" > "$endname"
      while true; do
        read -p "Confirm make video? (y/n)" yn
        case "$yn" in
          [Yy] ) echo "${i}$image" >> "$todo"; echo "$endname" >> "$tlist"; echo "$title" >> "$titles"; break;;
          [Nn] ) rm "$image"; rm "$endname"; exit;;
          * ) echo "Please answer y/Y or n/N.";;
        esac
      done
    else
      image="$endname"
      namer "tracks.txt"
      printf "%s\n" *.flac > "$endname"
      echo "${i}$image" >> "$todo"
      echo "$endname" >> "$tlist"
      echo "$title" >> "$titles"
    fi
  )
done

if [[ -e $todo ]]; then
  while IFS= read -r line; do
    todo_list+=( "$line" )
  done < "$todo"
fi
if [[ -e $tlist ]]; then
  while IFS= read -r line; do
    tlist_list+=( "$line" )
  done < "$tlist"
fi
if [[ -e $titles ]]; then
  while IFS= read -r line; do
    titles_list+=( "$line" )
  done < "$titles"
fi

clear

#Test just this :)
for i in "${!todo_list[@]}"; do
  folder="${todo_list[$i]}"; folder="${folder%/*}"
  printf "\nProcessing $folder..."
  (
    cd "$folder"
    namer "out.flac"
    out="$endname"
    while IFS= read -r line; do
      list+=( "$line" )
    done < "${tlist_list[$i]}"
    case ${#list[@]} in
      1) ffmpeg -loglevel error -i "${list[0]}" -vn -c:a copy "$out"
        ;;
      #Artwork removed automatically when concat-demuxing as below
      *) namer "concat.txt"
        concat="$endname"
        for j in "${list[@]}"; do
          m=0
          for k in "${!indices[@]}"; do
            [[ $j = ${indices[$k]} ]] && m=1 && echo "file '${wavfiles[$k]}'" >> "$concat" && break
          done
          if [[ $m -eq 0 ]]; then
            namer "${#indices[@]}.wav"
            ffmpeg -loglevel error -i "$j" "$endname"
            echo "file '$endname'" >> "$concat"
            wavfiles+=( "$endname" )
            indices+=( "$j" )
          fi
        done
        namer "out.wav"
        ffmpeg -loglevel error -f concat -safe 0 -i "$concat" -c copy "$endname"
        ffmpeg -loglevel error -i "$endname" "$out"
        rm "${wavfiles[@]}" "$concat" "$endname"
        ;;
    esac
    rm "${tlist_list[$i]}"
    printf "$folder/$out" > "$temp"
  )
  printf "Done!\n"
  namer "${titles_list[$i]}.mkv"
  echo "Encoding $endname..."
  ffmpeg -loglevel error -stats -loop 1 -framerate 2 -i "${todo_list[$i]}" -i "$(cat "$temp")" -c:v libx264 -preset slow -tune stillimage -crf 18 -c:a copy -shortest -pix_fmt yuv420p "$endname"
  echo "Done!"
  rm "${todo_list[$i]}" "$(cat "$temp")"
done
rm -f "$todo" "$prefs" "$temp" "$tlist" "$titles"

clear #Ok, this is a bit nitpicky
