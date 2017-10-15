#!/usr/bin/env python2
import math
import os
import time
import subprocess
import random
import threading
import ConfigParser
import RPi.GPIO as GPIO

MOUNT_DIR = '/run/media/alarm'
CONFIG_DIR =  '/home/alarm/.config'
CONFIG_FILE = 'pimusicplayer'
VOLUME = 50 # percentage

class MusicPlayer(threading.Thread):
	def __init__(self):
		threading.Thread.__init__(self)

		self.vol_mb = 2000 * math.log(VOLUME/100.0, 10) # volume in millibels
		self.omxplayer = None
		self.playlist_loaded = False
		self.config = None
		self.config_file_path = ''
		self.device = ''
		self.playlists = []
		self.playlist_index = 0
		self.playlist_path = ''
		self.music_files = []
		self.music_file_index = 0

		self.load_config()
		self.setup_gpio()

	def run(self):
		self.play_music()

	def load_config(self):
		config_dir_exp = os.path.expanduser(CONFIG_DIR)
		self.config_file_path = os.path.join(config_dir_exp, CONFIG_FILE)

		self.config = ConfigParser.ConfigParser()
		
		if os.path.isfile(self.config_file_path):
			self.config.read(self.config_file_path)
		else:
			if not os.path.exists(config_dir_exp):
				os.makedirs(config_dir_exp)
			self.config.add_section('Player')
			self.config.set('Player', 'previous_playlist', 'foo')
			self.write_conf_to_file()

	def write_conf_to_file(self):
		with open(self.config_file_path, 'wb') as conf_file:
			self.config.write(conf_file)

	def setup_gpio(self):
		GPIO.setmode(GPIO.BCM)
		GPIO.setup(17, GPIO.IN, pull_up_down=GPIO.PUD_DOWN) # set pin 17 as input
		GPIO.setup(22, GPIO.IN, pull_up_down=GPIO.PUD_DOWN) # set pin 22 as input

		# Check when 'next song' button is pressed (200ms for debouncing)
		GPIO.add_event_detect(17, GPIO.RISING, callback=lambda x: self.next_song(), bouncetime=200)

		# Check when 'next playlist' button is pressed (200ms for debouncing)
		GPIO.add_event_detect(22, GPIO.RISING, callback=lambda x: self.next_playlist(), bouncetime=200)

	def list_dirs(self, directory):
		"""Returns a list of directories in the given directory"""
		return [d for d in os.listdir(directory) if os.path.isdir(os.path.join(directory, d))]

	def find_device(self):
		"""Returns the mount directory for the first USB drive found"""
		while not os.path.exists(MOUNT_DIR):
			# Wait for mount directory to be created
			print "Waiting for udiskie to start"
			time.sleep(1)
			pass

		devices = self.list_dirs(MOUNT_DIR)

		while len(devices) == 0:
			print "No devices found"
			time.sleep(5)
			print "Retrying..."
			devices = self.list_dirs(MOUNT_DIR)
		
		return os.path.join(MOUNT_DIR, devices[0])

	def play_music(self):

		while True:

			self.device = self.find_device()

			print "Loaded device", self.device

			self.playlists = self.list_dirs(self.device)

			if len(self.playlists) == 0:
				print "No playlists found on device"
				time.sleep(5)
				pass
			else:
				random.shuffle(self.playlists)

				previous_playlist = self.config.get('Player', 'previous_playlist')

				if previous_playlist in self.playlists:
					self.playlist_index = self.playlists.index(previous_playlist)
				else:
					self.playlist_index = 0

				self.load_playlist()

				while True:
					if self.playlist_loaded: # False when changing playlists
						music_file = self.music_files[self.music_file_index]

						print "Playing song", music_file

						music_file_path = os.path.join(self.playlist_path, music_file)

						self.omxplayer = subprocess.Popen(["omxplayer", '--vol', str(self.vol_mb), music_file_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
						self.omxplayer.wait()

						output, error = self.omxplayer.communicate()

						# If the file's not found, we'll assume the drive was unplugged
						if (self.omxplayer.returncode == 1 and "not found" in output):
							print "Drive was unplugged"
							break

						print "Song completed"

						self.music_file_index += 1
						self.music_file_index %= len(self.music_files)

	def load_playlist(self):
		playlist = self.playlists[self.playlist_index]

		self.config.set('Player', 'previous_playlist', playlist)
		self.write_conf_to_file()

		print "Playing playlist", playlist

		# Text-to-speech the playlist name
		tts = subprocess.Popen(["flite", "-t", playlist], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		tts.wait()

		self.playlist_path = os.path.join(self.device, playlist)
		self.music_files = [f for f in os.listdir(self.playlist_path) if os.path.isfile(os.path.join(self.playlist_path, f))]
		random.shuffle(self.music_files)
		self.music_file_index = 0

		self.playlist_loaded = True

	def next_song(self):
		if self.omxplayer is not None:
			self.omxplayer.stdin.write("q")

	def next_playlist(self):
		print "Next playlist"

		self.playlist_loaded = False
		self.next_song()

		self.playlist_index += 1
		self.playlist_index %= len(self.playlists)

		self.load_playlist()

# Entry point
music_player = MusicPlayer()
music_player.daemon = True
music_player.start()

while True:
	time.sleep(1)