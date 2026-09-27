#!/usr/bin/env python3
"""Lets the app run in Apple-silicon iOS Simulators (iOS 26+ are arm64 only).

Google ML Kit ships its CocoaPods frameworks with x86_64 simulator and arm64
device slices only. This copies each framework's arm64 slice, re-tags every
object file as iOS Simulator (LC_BUILD_VERSION platform 2 -> 7), and wraps
both in an .xcframework next to the original. Simulator builds link the
patched copy (see the Podfile); device builds and the .ipa are untouched.

Run by the Podfile's post_install; safe to run again.
"""
import glob, os, plistlib, shutil, struct, subprocess, sys, tempfile

LC_BUILD_VERSION = 0x32
PLATFORM_IOS, PLATFORM_IOSSIMULATOR = 2, 7


def retag_object(data, base):
    magic, _, _, _, ncmds = struct.unpack_from('<IiiII', data, base)
    if magic != 0xfeedfacf:
        return
    off = base + 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, off)
        if cmd == LC_BUILD_VERSION and struct.unpack_from('<I', data, off + 8)[0] == PLATFORM_IOS:
            struct.pack_into('<I', data, off + 8, PLATFORM_IOSSIMULATOR)
        off += size


def retag(path):
    """Patches in place, so archives keep duplicate member names and their
    symbol index (offsets don't move)."""
    with open(path, 'r+b') as f:
        data = bytearray(f.read())
        if data[:8] == b'!<arch>\n':
            off = 8
            while off + 60 <= len(data):
                name = data[off:off + 16].decode().strip()
                size = int(data[off + 48:off + 58].decode().strip())
                start = off + 60
                if name.startswith('#1/'):
                    start += int(name[3:])  # BSD long name before the data
                retag_object(data, start)
                off += 60 + size
                off += off % 2
        else:
            retag_object(data, 0)
        f.seek(0)
        f.write(data)


def run(*args, cwd=None):
    subprocess.run(args, check=True, cwd=cwd, stdout=subprocess.DEVNULL)


def convert(framework):
    name = os.path.basename(framework)[:-len('.framework')]
    binary = os.path.join(framework, name)
    out = os.path.join(os.path.dirname(framework), name + '.xcframework')
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(binary):
        return
    shutil.rmtree(out, ignore_errors=True)
    with tempfile.TemporaryDirectory() as tmp:
        device, sim = os.path.join(tmp, 'device'), os.path.join(tmp, 'sim')
        shutil.copytree(framework, os.path.join(device, name + '.framework'), symlinks=True)
        shutil.copytree(framework, os.path.join(sim, name + '.framework'), symlinks=True)
        run('lipo', binary, '-thin', 'arm64', '-output',
            os.path.join(device, name + '.framework', name))

        arm64 = os.path.join(tmp, 'arm64.a')
        sim_arm64 = os.path.join(tmp, 'sim_arm64.a')
        run('lipo', binary, '-thin', 'arm64', '-output', arm64)
        shutil.copy(arm64, sim_arm64)
        retag(sim_arm64)
        run('lipo', binary, '-thin', 'x86_64', '-output', os.path.join(tmp, 'sim_x86_64.a'))
        run('lipo', '-create', os.path.join(tmp, 'sim_arm64.a'), os.path.join(tmp, 'sim_x86_64.a'),
            '-output', os.path.join(sim, name + '.framework', name))

        # Written by hand: some objects carry no platform, so
        # `xcodebuild -create-xcframework` can't tell device from simulator.
        os.makedirs(out)
        shutil.move(device, os.path.join(out, 'ios-arm64'))
        shutil.move(sim, os.path.join(out, 'ios-arm64_x86_64-simulator'))
        library = {'BinaryPath': name + '.framework/' + name,
                   'LibraryPath': name + '.framework', 'SupportedPlatform': 'ios'}
        with open(os.path.join(out, 'Info.plist'), 'wb') as f:
            plistlib.dump({
                'AvailableLibraries': [
                    {**library, 'LibraryIdentifier': 'ios-arm64',
                     'SupportedArchitectures': ['arm64']},
                    {**library, 'LibraryIdentifier': 'ios-arm64_x86_64-simulator',
                     'SupportedArchitectures': ['arm64', 'x86_64'],
                     'SupportedPlatformVariant': 'simulator'},
                ],
                'CFBundlePackageType': 'XFWK',
                'XCFrameworkFormatVersion': '1.0',
            }, f)
    print('arm64 simulator slice:', name)


if __name__ == '__main__':
    pods = sys.argv[1] if len(sys.argv) > 1 else 'Pods'
    for fw in glob.glob(os.path.join(pods, 'MLKit*/Frameworks/*.framework')) + \
              glob.glob(os.path.join(pods, 'MLImage/Frameworks/*.framework')):
        convert(fw)
