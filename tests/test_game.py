"""Execute the TASM-built COM in a real-mode CPU with small BIOS/DOS stubs.

Build first with BUILD.BAT in DOSBox. Requires Python 3 and `pip install unicorn`.
Run from the repository root: python -m unittest discover -s tests -v
This checks actual machine code; DOSBox remains the integration/runtime check.
"""

from collections import deque
from pathlib import Path
import re
import struct
import unittest

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_CODE
from unicorn.x86_const import (
    UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX, UC_X86_REG_DX,
    UC_X86_REG_SI, UC_X86_REG_DI, UC_X86_REG_SP, UC_X86_REG_CS,
    UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_EFLAGS,
)

ROOT = Path(__file__).resolve().parents[1]
SEGMENT = 0x1000
BASE = SEGMENT * 16
VGA = 0xA0000
DAY_TICKS = 0x1800B0


class Game:
    def __init__(self, keys=()):
        listing = (ROOT / 'BUILD/ZMEI.LST').read_text()
        self.symbols = {
            name.lower(): int(offset, 16)
            for name, offset in re.findall(
                r'^\s*(\w+)\s+(?:Near|Byte|Word)\s+DGROUP:([0-9A-F]+)\s*$',
                listing, re.MULTILINE,
            )
        }
        self.cpu = Uc(UC_ARCH_X86, UC_MODE_16)
        self.cpu.mem_map(0, 0x100000)
        self.cpu.mem_write(BASE + 0x100, (ROOT / 'BUILD/ZMEI.COM').read_bytes())
        for register in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
            self.cpu.reg_write(register, SEGMENT)
        self.cpu.reg_write(UC_X86_REG_EFLAGS, 0x202)
        self.keys = deque(keys)
        self.poll_keys = True
        self.ticks = deque()
        self.clock = 0
        self.clock_calls = 0
        self.files = {path.name: path.read_bytes() for path in ROOT.glob('*.bmp')}
        self.handles = {}
        self.opened = []
        self.output = ''
        self.modes = []
        self.exit_code = None
        self.cpu.hook_add(UC_HOOK_INTR, self.interrupt)

    def byte(self, name, value=None):
        address = BASE + self.symbols[name]
        if value is not None:
            self.cpu.mem_write(address, bytes([value]))
        return self.cpu.mem_read(address, 1)[0]

    def word(self, name, value=None):
        address = BASE + self.symbols[name]
        if value is not None:
            self.cpu.mem_write(address, struct.pack('<H', value))
        return struct.unpack('<H', self.cpu.mem_read(address, 2))[0]

    def positions(self, values=None):
        address = BASE + self.symbols['snake_cells']
        if values is not None:
            self.cpu.mem_write(address, struct.pack('<' + 'H' * len(values), *values))
        length = self.word('snake_length')
        return list(struct.unpack('<' + 'H' * length, self.cpu.mem_read(address, length * 2)))

    def color(self, position, value=None):
        offset = (position >> 8) * 640 + (position & 255) * 2
        if value is not None:
            for row in (0, 320):
                self.cpu.mem_write(VGA + offset + row, bytes([value, value]))
        return self.cpu.mem_read(VGA + offset, 1)[0]

    def carry(self, value):
        flags = self.cpu.reg_read(UC_X86_REG_EFLAGS)
        self.cpu.reg_write(UC_X86_REG_EFLAGS, (flags & ~1) | int(value))

    def interrupt(self, cpu, number, _):
        ax = cpu.reg_read(UC_X86_REG_AX)
        ah, al = ax >> 8, ax & 255
        if number == 0x10:
            if ah == 0x0F:
                cpu.reg_write(UC_X86_REG_AX, 0x5003)
            elif ah == 0:
                self.modes.append(al)
                cpu.mem_write(VGA, bytes(64000))
            else:
                raise AssertionError(f'Unexpected video function {ah:x}')
        elif number == 0x16:
            if ah == 1:
                flags = cpu.reg_read(UC_X86_REG_EFLAGS)
                available = self.keys and self.poll_keys
                cpu.reg_write(UC_X86_REG_EFLAGS, (flags & ~0x40) | (0 if available else 0x40))
            elif ah == 0:
                if not self.keys:
                    raise AssertionError('Unexpected blocking keyboard read')
                cpu.reg_write(UC_X86_REG_AX, self.keys.popleft() << 8)
            else:
                raise AssertionError(f'Unexpected keyboard function {ah:x}')
        elif number == 0x1A:
            assert ah == 0, 'Timer function must be selected on every call'
            tick = self.ticks.popleft() if self.ticks else self.clock
            self.clock = (tick + 1) % DAY_TICKS
            self.clock_calls += 1
            cpu.reg_write(UC_X86_REG_CX, tick >> 16)
            cpu.reg_write(UC_X86_REG_DX, tick & 0xFFFF)
            cpu.reg_write(UC_X86_REG_AX, 1)  # midnight indicator in AL
        elif number == 0x21:
            address = cpu.reg_read(UC_X86_REG_DS) * 16 + cpu.reg_read(UC_X86_REG_DX)
            if ah == 0x3D:
                name = bytes(cpu.mem_read(address, 128)).split(b'\0')[0].decode('ascii')
                self.carry(name not in self.files)
                if name in self.files:
                    self.opened.append(name)
                    self.handles[5] = self.files[name]
                    cpu.reg_write(UC_X86_REG_AX, 5)
            elif ah == 0x3F:
                data = self.handles[cpu.reg_read(UC_X86_REG_BX)]
                data = data[:cpu.reg_read(UC_X86_REG_CX)]
                if data:
                    cpu.mem_write(address, data)
                cpu.reg_write(UC_X86_REG_AX, len(data))
                self.carry(False)
            elif ah == 0x3E:
                del self.handles[cpu.reg_read(UC_X86_REG_BX)]
                self.carry(False)
            elif ah == 9:
                self.output += bytes(cpu.mem_read(address, 256)).split(b'$')[0].decode('ascii')
            elif ah == 2:
                self.output += chr(cpu.reg_read(UC_X86_REG_DX) & 255)
            elif ah == 0x4C:
                self.exit_code = al
                cpu.emu_stop()
            else:
                raise AssertionError(f'Unexpected DOS function {ah:x}')
        else:
            raise AssertionError(f'Unexpected interrupt {number:x}')

    def call(self, name, ax=0, dx=0):
        stack = self.symbols['stack_top'] - 2
        self.cpu.reg_write(UC_X86_REG_SP, stack)
        self.cpu.mem_write(BASE + stack, struct.pack('<H', 0x80))
        self.cpu.reg_write(UC_X86_REG_AX, ax)
        self.cpu.reg_write(UC_X86_REG_DX, dx)
        self.cpu.emu_start(BASE + self.symbols[name], BASE + 0x80, count=3000000)
        assert self.cpu.reg_read(UC_X86_REG_SP) == stack + 2, 'Unbalanced stack or instruction limit'
        assert not self.cpu.reg_read(UC_X86_REG_EFLAGS) & 0x400, 'Direction flag left set'
        return self.cpu.reg_read(UC_X86_REG_AX) & 255

    def run(self, on_move=None):
        if on_move:
            def hook(cpu, address, size, data):
                on_move(self)
            address = BASE + self.symbols['game_loop']
            self.cpu.hook_add(UC_HOOK_CODE, hook, begin=address, end=address)
        self.cpu.emu_start(BASE + 0x100, 0xFFFFF, count=30000000)
        assert self.exit_code is not None, 'Program did not exit within instruction limit'

    def prepare(self):
        self.call('initialize_snake')
        self.word('food_remaining', 10)
        self.call('draw_snake')


class GameTests(unittest.TestCase):
    def test_all_assets_render_exactly_and_count_food(self):
        game = Game()
        for name, data in game.files.items():
            with self.subTest(bitmap=name):
                game.cpu.mem_write(BASE + 0x90, name.encode() + b'\0')
                game.call('load_bitmap', dx=0x90)
                self.assertFalse(game.cpu.reg_read(UC_X86_REG_EFLAGS) & 1)
                game.call('draw_bitmap')
                pixels = data[1078:17078]
                rows = [b''.join(bytes([c, c]) for c in pixels[i:i + 160]) for i in range(0, 16000, 160)]
                expected = b''.join(row + row for row in rows)
                self.assertEqual(bytes(game.cpu.mem_read(VGA, 64000)), expected)
                self.assertEqual(game.word('food_remaining'), sum(c in (2, 3, 4) for c in pixels))
                self.assertFalse(game.handles)

    def test_normal_movement_in_all_free_directions(self):
        for direction, head in ((1, 0x403F), (2, 0x3F40), (4, 0x4140)):
            with self.subTest(direction=direction):
                game = Game()
                game.prepare()
                game.byte('snake_direction', direction)
                self.assertEqual(game.call('advance_snake'), 0)
                self.assertEqual(game.positions(), [head, 0x4040, 0x4041, 0x4042])
                self.assertEqual(game.color(0x4043), 0)
                self.assertEqual(game.color(head), 15)

    def test_full_width_and_board_edges(self):
        game = Game()
        game.prepare()
        game.positions([0x409E, 0x409D, 0x409C, 0x409B])
        game.byte('snake_direction', 3)
        self.assertEqual(game.call('advance_snake'), 0)
        self.assertEqual(game.positions()[0], 0x409F)
        self.assertEqual(game.color(0x409F), 15)
        self.assertEqual(game.call('advance_snake'), 1)
        for position, direction in ((0x4000, 1), (0x0040, 2), (0x6340, 4)):
            game.positions([position, 0x4041, 0x4042, 0x4043])
            game.byte('snake_direction', direction)
            self.assertEqual(game.call('advance_snake'), 1)

    def test_wall_and_self_collision(self):
        game = Game()
        game.prepare()
        game.byte('snake_direction', 3)
        self.assertEqual(game.call('advance_snake'), 1)
        game.byte('snake_direction', 1)
        game.color(0x403F, 15)
        self.assertEqual(game.call('advance_snake'), 1)

    def test_growth_and_duplicate_tail_lifetime(self):
        for color, length in ((2, 5), (4, 6)):
            with self.subTest(color=color):
                game = Game()
                game.prepare()
                game.color(0x403F, color)
                self.assertEqual(game.call('advance_snake'), 0)
                self.assertEqual(game.word('snake_length'), length)
                self.assertEqual(game.word('food_remaining'), 9)
                self.assertEqual(game.color(0x4043), 15)
                game.call('advance_snake')
                self.assertEqual(game.color(0x4043), 15 if color == 4 else 0)
                game.call('advance_snake')
                self.assertEqual(game.color(0x4043), 0)

    def test_shrink_spawns_food_including_after_double_growth(self):
        for double_growth in (False, True):
            game = Game()
            game.prepare()
            if double_growth:
                game.color(0x403F, 4)
                game.call('advance_snake')
            length = game.word('snake_length')
            food = game.word('food_remaining')
            next_head = game.positions()[0] - 1
            game.color(next_head, 3)
            game.call('advance_snake')
            self.assertEqual(game.word('snake_length'), length - 1)
            self.assertEqual(game.word('food_remaining'), food)
            self.assertEqual(game.color(0x4043), 2)
            for position in game.positions():
                self.assertEqual(game.color(position), 15)

    def test_minimum_length_and_level_completion(self):
        game = Game()
        game.prepare()
        game.word('snake_length', 2)
        game.word('food_remaining', 1)
        game.color(0x403F, 3)
        self.assertEqual(game.call('advance_snake'), 2)
        self.assertEqual(game.word('snake_length'), 2)
        self.assertEqual(game.word('food_remaining'), 0)

    def test_capacity_does_not_overwrite_bitmap_buffer(self):
        for length in (1023, 1024):
            for color in (2, 4):
                game = Game()
                game.word('snake_length', length)
                game.positions([0x4040] + [0x4041] * (length - 1))
                guard = BASE + game.symbols['bitmap_buffer']
                game.cpu.mem_write(guard, b'GUARD')
                game.word('food_remaining', 10)
                game.color(0x403F, color)
                game.call('advance_snake')
                self.assertEqual(game.word('snake_length'), 1024)
                self.assertEqual(bytes(game.cpu.mem_read(guard, 5)), b'GUARD')

    def test_input_reversal_and_quit_bindings(self):
        for key, direction in ((0x4D, 1), (0x48, 2), (0x50, 4), (0x4B, 1)):
            game = Game([key])
            game.call('read_direction')
            self.assertEqual(game.byte('snake_direction'), direction)
        for key in (0x01, 0x44):
            game = Game([key])
            game.call('read_direction')
            self.assertEqual(game.byte('quit_requested'), 1)

    def test_timer_low_word_and_midnight_wrap(self):
        for ticks in ((0xFFFF, 0xFFFF, 0x10000, 0x10001),
                      (DAY_TICKS - 1, DAY_TICKS - 1, 0, 1)):
            game = Game()
            game.ticks.extend(ticks)
            game.call('wait_for_move')
            self.assertEqual(game.clock_calls, 4)

    def test_bad_bitmaps_close_handles_and_report_failure(self):
        valid = Game().files['intro0.bmp']
        invalid = [b'', valid[:200], b'XX' + valid[2:]]
        for offset in (10, 14, 18, 22, 26, 28, 30):
            data = bytearray(valid)
            data[offset] ^= 1
            invalid.append(bytes(data))
        for data in invalid:
            game = Game()
            game.files['intro0.bmp'] = data
            game.call('load_bitmap', dx=game.symbols['intro_filename'])
            self.assertTrue(game.cpu.reg_read(UC_X86_REG_EFLAGS) & 1)
            self.assertFalse(game.handles)

    def test_full_program_menu_quit_and_missing_asset(self):
        game = Game([0x01])
        game.run()
        self.assertEqual(game.exit_code, 0)
        self.assertEqual(game.modes, [0x13, 3])
        game = Game()
        del game.files['intro0.bmp']
        game.run()
        self.assertEqual(game.exit_code, 1)
        self.assertIn('intro0.bmp', game.output)
        self.assertEqual(game.modes, [0x13, 3])

    def test_full_program_all_levels_and_victory(self):
        game = Game([0x3C, 0x39, 0x39, 0x39, 0x39, 0x01])
        # Deliver scripted screen keys only to blocking reads, not to the
        # in-game polling call; the CPU still executes all input code.
        game.poll_keys = False

        def finish_level(game):
            game.word('food_remaining', 1)
            game.color(0x403F, 2)

        game.run(finish_level)
        self.assertEqual(game.opened, ['intro0.bmp', 'level1.bmp', 'level2.bmp',
                                      'level3.bmp', 'level4.bmp', 'victor.bmp'])
        self.assertEqual(game.exit_code, 0)
        self.assertEqual(game.modes[-1], 3)

    def test_full_program_defeat_screen(self):
        game = Game([0x3B, 0x39, 0x01])
        game.poll_keys = False

        def hit_wall(game):
            game.color(0x403F, 15)

        game.run(hit_wall)
        self.assertEqual(game.opened[-1], 'losezz.bmp')
        self.assertEqual(game.exit_code, 0)


if __name__ == '__main__':
    unittest.main()
