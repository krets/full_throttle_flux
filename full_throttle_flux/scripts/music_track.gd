@tool
extends Resource
class_name MusicTrack

## Custom resource for defining music tracks with metadata
## Create .tres files in res://music/ pointing to audio files

@export_group("Audio")
## The audio file for this track (OGG, WAV, MP3)
@export var audio_stream: AudioStream

@export_group("Metadata")
## Display name of the track
@export var track_name: String = "Unknown Track"

## Artist or composer name
@export var artist: String = "Unknown Artist"

@export_group("Usage Flags")
## Can this track play during menus?
@export var use_in_menu: bool = true

## Can this track play during races?
@export var use_in_race: bool = true

## Get formatted display string
func get_display_text() -> String:
	return "%s - %s" % [track_name, artist]

## Check if track is valid (has audio)
func is_valid() -> bool:
	return audio_stream != null
