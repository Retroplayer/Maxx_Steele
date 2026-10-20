"""Windows/Linux/macOS USB serial console. Install pyserial==3.5 first."""

import argparse
import json
import threading
import time

import serial


class Remote:
    def __init__(self, port):
        self.serial = serial.Serial(port, 115200, timeout=0.2, write_timeout=2)
        self.lock = threading.Lock()

    def command(self, text):
        with self.lock:
            self.serial.write((text.strip() + "\n").encode("ascii"))
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                line = self.serial.readline()
                if not line:
                    continue
                try:
                    value = json.loads(line)
                except (ValueError, UnicodeError):
                    continue  # MicroPython startup/REPL text is not a response.
                if "ok" in value:
                    if not value["ok"]:
                        raise RuntimeError(value.get("error", "Command failed"))
                    return value
            raise TimeoutError("Pico did not reply; check firmware and USB port")

    def close(self):
        self.serial.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="For example COM5 or /dev/ttyACM0")
    args = parser.parse_args()
    remote = Remote(args.port)
    done = threading.Event()
    failed = []

    def keepalive():
        while not done.wait(0.5):
            try:
                remote.command("PING")
            except Exception as error:
                failed.append(str(error))
                done.set()
                return

    worker = threading.Thread(target=keepalive, daemon=True)
    try:
        print(remote.command("STATUS"))
        print("TAP FORWARD 100 | DOWN FORWARD | UP FORWARD | STOP | KEYS | STATUS | QUIT")
        worker.start()
        while not done.is_set():
            command = input("remote> ").strip()
            if command.upper() in ("QUIT", "EXIT"):
                break
            if command:
                try:
                    print(remote.command(command))
                except (RuntimeError, TimeoutError) as error:
                    print("Error:", error)
        if failed:
            print("USB connection failed:", failed[0])
    except (KeyboardInterrupt, EOFError):
        pass
    finally:
        done.set()
        if worker.is_alive():
            worker.join(timeout=4)
        try:
            remote.command("STOP")
            time.sleep(0.15)
        except Exception:
            pass  # Pico lease expiry handles a lost link while keys are held.
        remote.close()


if __name__ == "__main__":
    main()
