@tool
extends Resource
class_name MusicManifest

## Resource that holds references to all music tracks in the game.
## This is used instead of directory scanning because exported builds
## cannot iterate over res:// directories (they're packed into a PCK file).
##
## HOW TO USE:
## 1. Create MusicTrack .tres files for each song in res://music/
## 2. Create a music_manifest.tres file (right-click in FileSystem → New Resource → MusicManifest)
## 3. In the Inspector, add all your MusicTrack resources to the "tracks" array
## 4. Save the manifest - MusicPlaylistManager will load it automatically

## List of all music track resources in the game
@export var tracks: Array[MusicTrack] = []

## Get all tracks that can play in menus
func get_menu_tracks() -> Array[MusicTrack]:
	var result: Array[MusicTrack] = []
	for track in tracks:
		if track and track.is_valid() and track.use_in_menu:
			result.append(track)
	return result

## Get all tracks that can play during races
func get_race_tracks() -> Array[MusicTrack]:
	var result: Array[MusicTrack] = []
	for track in tracks:
		if track and track.is_valid() and track.use_in_race:
			result.append(track)
	return result

## Get count of valid tracks
func get_valid_track_count() -> int:
	var count := 0
	for track in tracks:
		if track and track.is_valid():
			count += 1
	return count
