# remove_chars_from_filename.sh
# Removes ? characters from the beginning of any file/directory

for file in ?*;
    do mv $file $(echo $file | sed -e 's/^.//'); 
done
