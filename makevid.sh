#!/bin/bash
shopt -s nullglob
set +o noclobber #set is posix, unlike shopt? idk. They have different opts.
#Requires ffmpeg 4+ and imagemagick

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
  y='-'
  words=( "$1" "${table_list[@]}" ); length=0
  for d in "${words[@]}"; do
    (( ${#d} > length )) && length=${#d}
  done
  div=$y$y
  header=${#1}
  while (( (header+(2*${#div})) < length )); do
    div+=$y
  done
  printf "%s%s%s\n" $div "$1" $div
  printf "%s\n" "${table_list[@]}"
  for (( c=0; c<$(( header+(2*${#div}) )); c++ )); do
    printf $y
  done
  printf "\n"
  unset table_list
}

#Preferences
namer "preferences.txt"
prefs="$PWD/$endname"

#Titles
namer "titles.txt"
titles="$PWD/$endname"

#Images
namer "images.txt"
images="$PWD/$endname"

#Tracklists
namer "tracklists.txt"
tlists="$PWD/$endname"

[[ $@ =~ [Ii] ]] && global=Interactive
[[ $@ =~ [Qq] ]] && global=Quiet

if [[ ! $global ]]; then
  echo "Select mode"
  select global in "Interactive" "Quiet"; do [[ $global ]] && break; done
fi

if [[ $global =~ ^Q ]]; then
  resize=0
  while true; do
    read -p "Resize images? (y/n)" yn
    case "$yn" in
      [Yy] ) resize=1; break;;
      [Nn] ) break;;
      * ) echo "Please answer y/Y or n/N.";;
    esac
  done
  if (( resize==1 )); then
    select opt in "1080p" "720p" "Custom"; do
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
fi

#first define makevid function.
#Return breaks a function. Exit does the whole script.
#makevid function as-is just does makevid w/ files in current directory. uses absolute paths, though, so can run anywhere, output will be where you started the fxn. Use this to recurse.

makevid () {

  [[ ! $(echo *.flac) ]] && return
  [[ ! $(echo *.{png,jpg,jpeg}) ]] && return

  title="$(basename "$PWD")"

  #Interactive (title+image)
  if [[ $global =~ ^I ]]; then

    clear; echo "$PWD"
    table_list=( "$title" )
    table "TITLE"

    #Title
    edit=0
    if ! grep -qs '^i' "$prefs"; then #q=quiet,s=noerrors
      printf "\n"
      while true; do
        read -p "Edit title? Type 'd' to disable prompt. (y/n/d)" ynd
        case "$ynd" in
          [Yy] ) edit=1; break;;
          [Nn] ) break;;
          [Dd] ) echo "i" >> "$prefs"; break;;
          * ) echo "Please answer y/Y, n/N, or d/D.";;
        esac
      done
    fi
    if (( edit==1 )); then
      title=''
      while [[ ! $title ]]; do

        #Read title & sanitize
        echo "Enter new title:"; read title
        title="$(echo "$title" | sed 's@/@-@g')"
        [[ ! $title ]] && title="$(basename "$PWD")"

        #Print title for confirmation
        clear; echo "$PWD"
        table_list=( "$title" )
        table "TITLE"
        printf "\n"

        #Confirm or reset
        while true; do
          read -p "Confirm title? (y/n)" yn
          case "$yn" in
            [Yy] ) break;;
            [Nn] ) title=''; break;;
            * ) echo "Please answer y/Y or n/N.";;
          esac
        done

      done

      #Print end result and continue
      clear; echo "$PWD"
      table_list=( "$title" )
      table "TITLE"
    fi

    #Image
    unset list
    for j in *.{png,jpg,jpeg}; do
      for k in {w,h}; do eval "$k=\$(identify -format \"%${k}\" \"$j\")"; done
      list+=( "${j} (${w}x${h})" )
      grep -qs '^n' "$prefs" && break
    done
    case ${#list[@]} in
      1) img="${list[0]}"
        ;;
      *) printf "\nSelect image\n"
        select img in "${list[@]}" "Always autoselect first image."; do
          if [[ $img = *. ]]; then
            img="${list[0]}"
            echo "n" >> "$prefs"
            break
          elif [[ $img ]]; then
            break
          fi
        done
        ;;
    esac
    table_list=( "$img" )
    printf "\n"
    table "IMAGE"
    newline=0
    name="${img% (*)}"; dim="${img##* (}"; dim="${dim%)}"; w="${dim%x*}"; h="${dim#*x}"

    #Image resize
    s=$(grep -s '^s' "$prefs"); res=${s#s}
    if [[ ! $s ]]; then
      resize=0
      printf "\n" && newline=1
      while true; do
        read -p "Resize image? (y/n)" yn
        case "$yn" in
          [Yy] ) resize=1; break;;
          [Nn] ) break;;
          * ) echo "Please answer y/Y or n/N.";;
        esac
      done
      if (( resize==1 )); then
        select opt in "1080p" "720p" "Custom"; do
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
      #Apply to all
      while true; do
        read -p "Apply to all images? (y/n)" yn
        case "$yn" in
          [Yy] ) echo "s${res}" >> "$prefs"; break;;
          [Nn] ) break;;
          * ) echo "Please answer y/Y or n/N.";;
        esac
      done
    fi

  #Quiet (title+image)
  else
    for j in *.{png,jpg,jpeg}; do name="$j"; break; done
    for k in {w,h}; do eval "$k=\$(identify -format \"%${k}\" \"$name\")"; done
  fi

  #Actual resize, either read from prefs or stored from above
  if [[ $res ]]; then
    (( w>h )) && c='^' || c=''
    namer "${name%.*}.png" #Sets endname to non-taken filename
    if [[ $global =~ ^I ]]; then
      (( newline==0 )) && printf "\n" && newline=1
      printf "Resizing to ${res}p..."
    fi
    convert "$name" -resize ${res}x${res}$c "$endname"
    for k in {w,h}; do eval "$k=\$(identify -format \"%${k}\" \"$endname\")"; done
    [[ $global =~ ^I ]] && printf "Done!\n" && echo "Resized image: $name (${w}x${h})"
  else
    namer "$name"
    cp "$name" "$endname"
  fi

  #Bad dimension fix (BOTH MODES, but no msgs. in quiet)
  if [[ $(( w%2 )) -ne 0 || $(( h%2 )) -ne 0 ]]; then
    if [[ $global =~ ^I ]]; then
      (( newline==0 )) && printf "\n" && newline=1
      printf "Bad dimensions, shaving..."
    fi
    w=$(( w-(w%2) )); h=$(( h-(h%2) ))
    convert "$endname" -crop ${w}x${h}+0+0 "$endname"
    [[ $global =~ ^I ]] && printf "Done!\n" && echo "Shaved image: $name (${w}x${h})"
  fi

  #Free up endname variable (both modes)
  image="$endname"

  #Interactive (audio)
  if [[ $global =~ ^I ]]; then
    #Track selection
    for k in *.flac; do table_list+=( "$k" ); done
    flac_list=( "${table_list[@]}" )
    printf "\n"
    table "AUDIO" #or fnum
    printf "\n"
    edit=0
    if ! grep -qs '^r' "$prefs"; then
      while true; do
        read -p "Edit tracklist? Type 'd' to disable prompt. (y/n/d)" ynd
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
        clear; echo "$PWD"
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

    #Confirm and finish
    namer "tracks.txt"
    printf "%s\n" "${flac_list[@]}" > "$endname"
    while true; do
      read -p "Confirm make video? (y/n)" yn
      case "$yn" in
        [Yy] ) echo "$PWD/$image" >> "$images"
              echo "$PWD/$endname" >> "$tlists"
              echo "$title" >> "$titles"
              break
              ;;
        [Nn] ) rm "$image"
              rm "$endname"
              return
              ;;
        * ) echo "Please answer y/Y or n/N.";;
      esac
    done

  #Quiet (audio)
  else
    namer "tracks.txt"
    printf "%s\n" *.flac > "$endname"
    echo "$PWD/$image" >> "$images"
    echo "$PWD/$endname" >> "$tlists"
    echo "$title" >> "$titles"
  fi

}

#Recursion
delve () {
  for i in */; do
    ( cd "$i"; delve )
  done
  makevid
}

#Main
for i in */; do
  ( cd "$i"; [[ $@ =~ [Rr] ]] && delve || makevid )
done
makevid

#Prepare to makevid
if [[ -e $titles ]]; then
  #Read all titles...
  while IFS= read -r line; do
    titles_list+=( "$line" )
  done < "$titles"
  #images...
  while IFS= read -r line; do
    images_list+=( "$line" )
  done < "$images"
  #and tracklists.
  while IFS= read -r line; do
    tlists_list+=( "$line" )
  done < "$tlists"
  #If one file exists, they all do.
fi

#Processing on fresh screen. Clear screen on interactive, regardless.
printf "\n"

#Actual makevid. Cycle through indices.
for i in "${!titles_list[@]}"; do

  folder="${images_list[$i]}"; folder="${folder%/*}"
  printf "Processing $folder..."
  (
    cd "$folder"

    #Read tracklist
    while IFS= read -r line; do
      tracks+=( "$line" )
    done < "${tlists_list[$i]}"

    #Name output
    namer "out.flac"
    out="$endname"

    #Process tracks, 1 or more
    case ${#tracks[@]} in
      1) ffmpeg -loglevel error -i "${tracks[0]}" -vn -c:a copy "$out"
        ;;
      #Artwork removed automatically when concat-demuxing wavs
      *) namer "concat.txt"
        concat="$endname"
        for j in "${tracks[@]}"; do
          m=0
          for k in "${!flacs[@]}"; do
            [[ $j = ${flacs[$k]} ]] && m=1 && echo "file '${wavs[$k]}'" >> "$concat" && break
          done
          if [[ $m -eq 0 ]]; then
            namer "n.wav"
            ffmpeg -loglevel error -i "$j" "$endname"
            echo "file '$endname'" >> "$concat"
            wavs+=( "$endname" )
            flacs+=( "$j" )
          fi
        done
        namer "out.wav" #Name concat wav file
        ffmpeg -loglevel error -f concat -safe 0 -i "$concat" -c copy "$endname"
        ffmpeg -loglevel error -i "$endname" "$out"
        rm "${wavs[@]}" "$concat" "$endname"
        ;;
    esac

    #Applies to any # of tracks, so cleanup tracklist here
    rm "${tlists_list[$i]}"

    #Absolute path to output stored in prefs
    printf "$PWD/$out" > "$prefs"
  )

  printf "Done!\n"

  #Make vid (finally)
  namer "${titles_list[$i]}.mkv"
  echo "Encoding $endname..."

  ffmpeg -loglevel error -stats -loop 1 -framerate 2 -i "${images_list[$i]}" -i "$(cat "$prefs")" -c:v libx264 -preset slow -tune stillimage -crf 18 -c:a copy -shortest -pix_fmt yuv420p "$endname"

  printf "Done!\n\n" # A matter of taste, I guess.

  #Cleanup image/audio
  rm "${images_list[$i]}" "$(cat "$prefs")"
done

#Cleanup text files
rm -f "$prefs" "$tlists" "$images" "$titles"
