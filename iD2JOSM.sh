#!/bin/sh

URL=https://raw.githubusercontent.com/escoand/JOSM-iD-preset/master/output

rm -rf output/
mkdir -p output/

# extract features
if [ -n "$1" ]; then
	rm -rf features/
	mkdir -p features/

	cat iD/data/feature-icons.json |
	sed "s/},/},|/g; s/^{//; s/}$//" |
	tr "|" "\n" |
	sed -n 's/^"\([^"]*\)":.*"24":\[\([0-9]*\),\([0-9]*\)\].*/\1 \2 \3/p' |
	while read N X Y; do
		convert iD/dist/img/maki-sprite.png -crop 24x24+$X+$Y features/$N.png
	done
fi

# category
category() {
	GID=$(echo $2 | cut -d- -f2-)
	GFILE=iD/data/presets/categories/$GID.json
	GNAME=$(sed -n 's/.*"name" *: *"\(.*\)".*/\1/p' $GFILE)
	GICON=$(sed -n 's/.*"icon" *: *"\(.*\)".*/\1/p' $GFILE | sed 's/^category-//')

	# icon
	GICON=$(icon $1 category "$GICON" $GFILE)

	# begin
	echo "$3<!-- $1 | $2 | $3 -->" >> output/preset.xml
	echo "$3<group name=\"$GNAME\" icon=\"$URL/$GICON.png\">" >> output/preset.xml

	# members
	sed -n '/"members" *: *\[/,/\]/p' $GFILE |
	grep -vE "\[|\]" |
	sed -n 's/.*"\([^"]*\)".*/\1/p' |
	while read MEMBER; do
		item $1 $MEMBER "$3	"
	done

	# end
	echo "$3</group>" >> output/preset.xml
}

# item
item() {
	IFILE=iD/data/presets/presets/$2.json
	INAME=$(sed -n 's/.*"name" *: *"\(.*\)".*/\1/p' $IFILE)
	IICON=$(sed -n 's/.*"icon" *: *"\(.*\)".*/\1/p' $IFILE)
	case $1 in
		area)		ITYPE=closedway ;;
		line)		ITYPE=way ;;
		point)		ITYPE=node ;;
		relation)	ITYPE=relation ;;
		vertex)		ITYPE=node ;;
		*)		ITYPE= ;;
	esac

	# icon
	IICON=$(icon $1 $(echo $2 | cut -d/ -f1) "$IICON" $IFILE)

	# begin
	echo "$3<!-- $1 | $2 | $3 -->" >> output/preset.xml
	echo "$3<item name=\"$INAME\" icon=\"$URL/$IICON.png\" type=\"$ITYPE\">" >> output/preset.xml
	echo "$3	<label text=\"Edit $INAME\" />" >> output/preset.xml
	echo "$3	<space />" >> output/preset.xml

	# keys
	sed -n '/"tags" *: *{/,/}/p' $IFILE |
	sed -n 's/.*"\([^"]*\)" *: *"\([^"]*\)".*/\1 \2/p' |
	while read KEY VALUE; do
		echo "$3	<key key=\"$KEY\" value=\"$VALUE\" />" >> output/preset.xml
	done

	# optional
	echo "$3	<optional>" >> output/preset.xml
	sed -n '/"fields" *: *{/,/}/p' $IFILE |
	sed -n 's/.*"\([^"]*\)".*/\1/p' |
	while read KEY; do
		if grep -q "^$KEY	" mapping.txt; then
			grep "^$KEY	" mapping.txt |
			cut -f2- |
			sed "s/^/$3		/" >> output/preset.xml
		else
			echo "$3		<text key=\"$KEY\" text=\"$KEY\" />" >> output/preset.xml
		fi
	done
	echo "$3	</optional>" >> output/preset.xml

	# end
	echo "$3</item>" >> output/preset.xml
}

# icon
icon() {
	CATEGORY=$2
	FEATURE=${3:-marker-stroked}

	# svg id
	if [ "$2-$3" = category-restriction -o "$2-$3" = category-route -o "$2-$3" = type-restriction ]; then
		SVG=relation-$3
		CATEGORY=category
	elif [ "$2-$3" = category-path -o "$2-$3" = category-rail -o "$2-$3" = category-roads ]; then
		SVG=$2-$3
	elif [ "$1-$2-$3" = line-category-water ]; then
		SVG=$2-$3
		FEATURE=${3}2
	elif [ "$2" = line ]; then
		SVG=highway-road
	elif [ "$2-$3" = railway-railway-light-rail ]; then
		SVG=railway-light_rail
		FEATURE=$(echo $3 | cut -d- -f2-)
	elif [ "$2-$3" = relation-relation ]; then
		SVG=$2-generic
	elif [ "$2-$3" = type-route-foot ]; then
		SVG=relation-route-hiking
		CATEGORY=$(echo $3 | cut -d- -f1)
		FEATURE=$(echo $3 | cut -d- -f2-)
	elif [ "$2-$3" = type-route-master ]; then
		SVG=g3421
		CATEGORY=$(echo $3 | cut -d- -f1)
		FEATURE=$(echo $3 | cut -d- -f2-)
	elif [ "$2-$(echo $3 | cut -d- -f1)" = type-restriction ]; then
		SVG=relation-$(echo $3 | cut -d- -f2,3)
		CATEGORY=$(echo $3 | cut -d- -f1)
		FEATURE=$(echo $3 | cut -d- -f2,3)
	elif [ "$2" = type ]; then
		SVG=relation-$3
		CATEGORY=$(echo $3 | cut -d- -f1)
		FEATURE=$(echo $3 | cut -d- -f2-)
	elif [ "$1" = line -o "$1" = relation ]; then
		SVG=$3
		FEATURE=$(echo $3 | cut -d- -f2-)

	# features
	elif [ "$1" = area -a "$2" = amenity ]; then
		CATEGORY=area
	elif [ "$1" = point -o "$1" = vertex ]; then
		CATEGORY=point

	fi
	if [ -f output/$CATEGORY-$FEATURE.png ]; then
		true

	# svg
	elif grep -q " id=\"$SVG\"" iD/svg/*-presets.svg; then
		inkscape -z -j -i $SVG -e output/$CATEGORY-$FEATURE.png $(grep -l "$SVG" iD/svg/*-presets.svg | head -n1) >&2

	# feature
	elif [ -f features/$FEATURE.png ]; then

		# background
		convert -size 60x60 xc:"rgba(0,0,0,0)" png:- |
		(
			# red
			if [  "$CATEGORY-$FEATURE" = landuse-building -o "$CATEGORY" = building ]; then
				convert - -fill "RGBA(224,110,95,0.3)" -stroke "#E06E5F" -draw "rectangle 10,10 50,50" png:-
			# violet
			elif [  "$CATEGORY-$FEATURE" = landuse-industrial ]; then
				convert - -fill "RGBA(228,164,245,0.3)" -stroke "#E4A4F5" -draw "rectangle 10,10 50,50" png:-
			# orange
			elif [  "$CATEGORY-$FEATURE" = landuse-commercial -o "$CATEGORY-$FEATURE" = landuse-shop ]; then
				convert - -fill "RGBA(234,176,86,0.3)" -stroke "#EAB056" -draw "rectangle 10,10 50,50" png:-
			# green
			elif [ "$CATEGORY" = landuse -o "$CATEGORY" = leisure ]; then
				convert - -fill "RGBA(140,208,95,0.2)" -stroke "#8CD05F" -draw "rectangle 10,10 50,50" png:-
			# blue
			elif [ "$CATEGORY" = natural ]; then
				convert - -fill "RGBA(119,211,222,0.3)" -stroke "#77D3DE" -draw "rectangle 10,10 50,50" png:-
			# grey
			elif [ "$CATEGORY" = area -o "$CATEGORY" = category ]; then
				convert - -fill "RGBA(170,170,170,0.3)" -stroke "#AAA" -draw "rectangle 10,10 50,50" png:-
			else
				cat
			fi
		) | (
			if [ "$CATEGORY" != point ]; then
				convert - \
					-fill white -stroke "RGBA(0,0,0,0.2)" -draw "circle 10,10 10,13.5" \
					-fill white -stroke "RGBA(0,0,0,0.2)" -draw "circle 10,50 10,53.5" \
					-fill white -stroke "RGBA(0,0,0,0.2)" -draw "circle 50,10 50,13.5" \
					-fill white -stroke "RGBA(0,0,0,0.2)" -draw "circle 50,50 50,53.5" \
					png:-
			else
				cat
			fi
		) |

		# foreground
		convert - \
			features/$FEATURE.png -gravity Center -composite \
			output/$CATEGORY-$FEATURE.png >&2

	# end
	else
		echo "output/$CATEGORY-$FEATURE.png missing ($1|$2|$3|$4)" >&2
		return
	fi
	echo $CATEGORY-$FEATURE
	echo "$CATEGORY-$FEATURE ($1|$2|$3|$4)" >&2
}

# begin
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > output/preset.xml
echo "<presets xmlns=\"http://josm.openstreetmap.de/tagging-preset-1.0\">" >> output/preset.xml

# defaults
cat iD/data/presets/defaults.json |
while read LINE; do
	VALUE=$(echo "$LINE" | cut -d'"' -f2)
	if echo "$LINE" | grep -q ":"; then
		TYPE=$VALUE
	elif echo "$VALUE" | grep -q "^category-"; then
		category $TYPE $VALUE "	"
	elif echo "$LINE" | grep -qvE "\[|\{|\}|\]"; then
		item $TYPE $VALUE "	" $TYPE
	fi
done

# end
echo "</presets>" >> output/preset.xml
