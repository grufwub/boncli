#!/bin/python3

# TODO: handle outputting selected files in manner readable by bash variable

import os
import sys
import stat
import pwd
import argparse
import curses
import re

ARG_DICT = {'preselected': [], 'start_dir': '', 'lowest_dir': '', 'output_file': ''}

RESULT_DIRCHANGE = 0
RESULT_SELCHANGE = 1
RESULT_EXIT = 2
RESULT_NONE = 3

FILE_RESULTS='/tmp/file_picker.results'

HEADER = "\n\tFile Picker\n" + "\t[UP = up, DOWN = down, LEFT = go back dir, RIGHT = enter dir, SPACE = select file/dir, Q = quit]\n\n" + "\tCurrent directory: %s\n\n"
HEADER_LINES = len(HEADER.split('\n'))
HEADER += "\n\n"
DISPLAY_LINE = HEADER_LINES - 1
HEADER_LINES += 2
DIR_ITEM = "\t[%s]\t%s%s\t\t\t\t\t\n"

USER_ID = os.getuid()

class DirItem:
	def __init__(self, title = "", path = "", read_error = False, filemode = "", owner = "", islink = False, isfile = True, readable = True):
		self.title = title
		self.path = path
		self.read_error = read_error
		self.filemode = filemode
		self.owner = owner
		self.islink = islink
		self.isfile = isfile
		self.readable = readable

class MenuInstance:
	def __init__(self, dir = "", preselected = list()):
		"""
		Initialization
		"""
		self.screen = None

		self.width = 0
		self.height = 0
		self.max_lines = 0
		self.drawline_start = len(HEADER.split('\n'))

		self.prev_dir = ""
		self.cur_dir = dir
		self.next_dir = ""

		self.index_sel = 0
		self.menu_offset = 0

		self.dir_items = list()
		self.selected_items = preselected

	def start(self):
		"""
		Start curses session
		"""
		# Create screen, enable keypad
		self.screen = curses.initscr()
		self.screen.keypad(True)

		# Setup terminal preferences in use with curses on-screen
		curses.noecho()
		curses.cbreak()
		curses.curs_set(False)

		# Get terminal dimensions
		self.max_lines = curses.LINES
		self.height, self.width = self.screen.getmaxyx()

	def close(self):
		"""
		Closes curses session
		"""
		# Clear the screen, undo curses terminal preferences and end
		self.screen.clear()
		self.screen.refresh()
		self.screen.keypad(False)
		curses.nocbreak()
		curses.echo()
		curses.endwin()

	def _get_dir_items(self):
		"""
		Fetch list of DirItems for files/dir in current directory
		"""
		# Clear list of previous items, fetch current directory contents then sort
		item_backup = self.dir_items
		try:
			items = os.listdir(self.cur_dir)
			items.sort()
			self.dir_items.clear()

			# For each item check if file/dir, generate full path and store all this under a
			# new instance of DirItem class
			for item in items:
				path = os.path.join(self.cur_dir, item)
				try:
					fileinfo = os.stat(path)
					userinfo = pwd.getpwuid(fileinfo.st_uid)
					filemode = stat.filemode(fileinfo.st_mode)
					isowner = fileinfo.st_uid == USER_ID
					readable = (isowner and filemode[1] == 'r') or (not isowner and filemode[4] == 'r') or (fileinfo.st_gid == userinfo.pw_gid and filemode[7] == 'r')
					dir_item = DirItem(title = item, path = path, filemode = filemode, owner = userinfo.pw_name, islink = os.path.islink(path), isfile = not filemode.startswith('d'), readable = readable)
				except:
					dir_item = DirItem(title = item, path = path, read_error = True, readable = False)
				finally:
					self.dir_items.append(dir_item)
		except:
			self.cur_dir = self.prev_dir
			self.dir_items = item_backup

	def run_loop(self):
		"""
		Main run loop
		"""
		# Get current directory items
		self._get_dir_items()

		# Initial draw
		# TODO: separate header so only 'current directory: ____' is redrawn, initial line is not
		self.screen.clear()
		self._draw_header()
		self._draw_dir_items()
		self.screen.refresh()

		# wWile loop awaiting input:
		# - on input result of 'LEFT' or 'RIGHT' (RESULT_DIRCHANGE) will break from loop,
		#   move next stored directory variable into current, then restart main run loop.
		# - on input result of 'UP', 'DOWN' or 'SPACE' changes the content only on lines
		#   with directory contents (NOT header) then refreshes screen and continues loop
		while True:
			result = self._handle_input()
			if result == RESULT_EXIT: return
			if result == RESULT_DIRCHANGE: break
			if result == RESULT_SELCHANGE:
				self._draw_dir_items()
				self.screen.refresh()
		if self.next_dir != "":
			self.prev_dir = self.cur_dir
			self.cur_dir = self.next_dir
			self.next_dir = ""
		self.run_loop()

	def _draw_header(self):
		"""
		Draws header above list of items
		"""
		self.screen.addstr(HEADER % self.cur_dir, curses.A_BOLD)

	def _draw_dir_items(self):
		"""
		Draws list of DirItems
		"""
		# Iterate through directory listing lines (end of header to max terminal line count)
		item_index = self.menu_offset
		for i in range(self.drawline_start - 1, self.max_lines - 1):
			# Only attempt to read then draw from dir_items if index within bounds
			if self.menu_offset <= item_index < len(self.dir_items):
				item = self.dir_items[item_index]

				# Add proceeding slash to indicate directory
				dirslash = "" if item.isfile else "/"

				# Highlight selected items with [*] vs. [ ]
				selected = "*" if item.path in self.selected_items else " "

				# Print string with reverse cursor if highlighted
				if item_index == self.index_sel:
					text = DIR_ITEM % (selected, item.title, dirslash)
					self.screen.addstr(i, 0, text, curses.A_REVERSE)
				else:
					text = DIR_ITEM % (selected, item.title, dirslash)
					self.screen.addstr(i, 0, text)
			# Once we have exhausted list bounds, draw blank strings
			else:
				self.screen.addstr(i, 0, "\t\t\t\t\t\n")
			item_index +=  1

	def _handle_input(self):
		"""
		Handle input from run loop. Loop stalls until getkey() returns value.
		Only returns true if item selected or 'back/forward' pressed
		"""
		key = self.screen.getkey()

		# Reset display line if text written
		self.screen.addstr(DISPLAY_LINE, 0, "\t\t\t\t\t\n")

		if key == "KEY_UP":
			# Move up list, inform selection change
			self._decrement_selected()
			return RESULT_SELCHANGE
		elif key == "KEY_DOWN":
			# Move down list, inform selection change
			self._increment_selected()
			return RESULT_SELCHANGE
		elif key == "KEY_LEFT":
			# Go back a directory by setting value in next_dir, reset
			# selected item + menu line offset then inform directory change.
			# Unless cur_dir == ARG_DICT['lowest_dir'] in which case do nothing
			if ARG_DICT['lowest_dir'] != '' and self.cur_dir == ARG_DICT['lowest_dir']: return RESULT_NONE
			self.next_dir = re.sub("[^\/]+\/*$", "", self.cur_dir)
			if self.next_dir != '/': self.next_dir = re.sub("\/$", "", self.next_dir)
			self.index_sel = 0
			self.menu_offset = 0
			return RESULT_DIRCHANGE
		elif key == "KEY_RIGHT":
			if len(self.dir_items) == 0: return RESULT_NONE
			if not self.dir_items[self.index_sel].isfile:
				# Enter a directory by setting value in next_dir, reset selected item
				# + menu line offset then inform directory change	
				path = os.path.join(self.cur_dir, self.dir_items[self.index_sel].title)
				if not self.dir_items[self.index_sel].readable:
					self._display_warning("NO READ PERMISSION FOR: %s" % path)
				elif self.dir_items[self.index_sel].read_error:
					self._display_warning("ERROR READING: %s" % path)
				else:
					self.next_dir = path
					self.index_sel = 0
					self.menu_offset = 0
					return RESULT_DIRCHANGE
		elif key == " ":
			# Selected item at currently selected index, inform selection change
			path = os.path.join(self.cur_dir, self.dir_items[self.index_sel].title)
			if not self.dir_items[self.index_sel].readable:
				self._display_warning("NO READ PERMISSION FOR: %s" % path)
			elif self.dir_items[self.index_sel].islink:
				self._display_warning("CANNOT SELECT A SYMLINK: %s" % path)
			elif self.dir_items[self.index_sel].read_error:
				self._display_warning("ERROR READING: %s" % path)
			else:
				self._select_item()
				return RESULT_SELCHANGE
		elif key == "q":
			# Return exit code to return from run_loop and stop MenuInstance main execution loop
			return RESULT_EXIT

		# No result. Maybe handle in future?
		return RESULT_NONE

	def _decrement_selected(self):
		"""
		Decrement selected item index, rolling over if hits top of menu
		"""
		length = len(self.dir_items)

		# 0 or 1 items to display, can't move cursor
		if length <= 1: return

		# Check if directory items has overspill on menu lines, then handle
		# selected index and menu offset values accordingly
		menu_overspill = (length > self.max_lines - self.drawline_start)
		if 0 < self.index_sel <= (length - 1):
			if menu_overspill and self.menu_offset == self.index_sel:
				self.menu_offset -= 1
			self.index_sel -= 1
		else:
			self.index_sel = length - 1
			if menu_overspill:
				self.menu_offset = length + self.drawline_start - self.max_lines

	def _increment_selected(self):
		"""
		Increment selected item index, rolling over if hits bottom of menu
		"""
		length = len(self.dir_items)

		# 0 or 1 items to display, can't move cursor
		if length <= 1: return

		# Handle selected item and menu offset values, increasing menu offset value
		# if index is at max drawable line but not yet at end of directory items
		if 0 <= self.index_sel < (length - 1):
			if self.index_sel == (self.menu_offset + self.max_lines - self.drawline_start - 1):
				self.menu_offset += 1
			self.index_sel += 1
		else:
			self.index_sel = 0
			self.menu_offset = 0

	def _display_warning(self, text = ""):
		"""
		Display warning to user on 'display line' and refresh screen straight-away
		"""
		printstr = "\t%s\n" % text
		self.screen.addstr(DISPLAY_LINE, 0, printstr, curses.A_REVERSE)
		self.screen.refresh()

	def _select_item(self):
		"""
		Adds path of item at index to list of selected items, or removes if already selected
		"""
		# No items on screen, do nothing
		if len(self.dir_items) == 0:
			return

		# If item in list, remove. Else, add
		if self.dir_items[self.index_sel].path in self.selected_items:
			self.selected_items.remove(self.dir_items[self.index_sel].path)
		else:
			self.selected_items.append(self.dir_items[self.index_sel].path)

	def get_selected(self):
		return self.selected_items

def read_arguments(args):
	"""
	Read provided arguments and add values to global ARG_DICT when found.
	Unsupported arguments print usage help
    """
	i = 0
	arglen = len(args)
	while i < arglen:
		if args[i] == '-p' or args[i] == '--pre-selected':
			if (i + 1) >= arglen: usage()
			else: ARG_DICT['preselected'] = args[i+1]
		elif args[i] == '-s' or args[i] == '--start-dir':
			if (i + 1) >= arglen: usage()
			else: ARG_DICT['start_dir'] = args[i+1]
		elif args[i] == '-l' or args[i] == '--lowest-dir':
			if (i + 1) >= arglen: usage()
			else: ARG_DICT['lowest_dir'] = args[i+1]
		elif args[i] == '-o' or args[i] == '--output':
			if (i + 1) >= arglen: usage()
			else: ARG_DICT['output_file'] = args[i+1]
		else:
			usage()
		i += 2

def usage():
	print("file_picker.py        -p / --pre-selected        provide ':' separated list of preselected files")
	print("                      -s / --start-dir           set starting directory file picker beings at") 
	print("                      -l / --lowest-dir          set lowest directory user is allowed to navigate to")
	print("                      -o / --output              provide filename to write results to (instead of printing to terminal)")
	sys.exit(1)

if __name__ == "__main__":
	# Read arguments
	read_arguments(sys.argv[1:])

	if ARG_DICT['start_dir'] != '':
		start_dir = ARG_DICT['start_dir']
	else:
		start_dir = os.path.expanduser('~')

	if len(ARG_DICT['preselected']) > 0:
		items = ARG_DICT['preselected'].split(':')
		menu = MenuInstance(dir = start_dir, preselected = items)
	else:
		menu = MenuInstance(dir = start_dir)
	
	try:
		menu.start()
		menu.run_loop()
	finally:
		selected = menu.get_selected()
		menu.close()

		# if requested print final results to file, else print
		if ARG_DICT['output_file'] != '':
			f = open(ARG_DICT['output_file'], 'w')
			for item in selected: f.write(item + '\n')
			f.close()
		else:
			for item in selected: print(item)