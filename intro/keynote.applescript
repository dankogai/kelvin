-- Opens a .pptx in Keynote, saves it as a .key and exports a .pdf beside it:
-- osascript keynote.applescript /absolute/path/kelvin-intro.pptx [image-folder]
-- Works on the document this opens, whatever else Keynote has open, and
-- leaves those alone.
on run argv
	set pptxPath to item 1 of argv
	set stem to text 1 thru -6 of pptxPath
	tell application "Keynote"
		activate
		set alreadyOpen to id of every document
	end tell
	-- by Launch Services: Keynote's sandbox refuses a path a script gives it
	do shell script "open -a Keynote " & quoted form of pptxPath
	tell application "Keynote"
		set theDoc to missing value
		-- an imported file takes a while
		repeat 60 times
			repeat with d in documents
				if alreadyOpen does not contain (id of d) then set theDoc to contents of d
			end repeat
			if theDoc is not missing value then exit repeat
			delay 1
		end repeat
		if theDoc is missing value then error "Keynote did not open " & pptxPath
		save theDoc in (POSIX file (stem & ".key"))
		export theDoc to (POSIX file (stem & ".pdf")) as PDF with properties {PDF image quality:Best}
		if (count of argv) > 1 then
			export theDoc to (POSIX file (item 2 of argv)) as slide images with properties {image format:PNG}
		end if
		close theDoc saving no
	end tell
	return stem
end run
