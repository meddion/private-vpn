import datetime
import subprocess
import time

# The maximum idle time in minutes before shutting down.
MAX_IDLE_MINUTES = 15


def get_last_handshake_time():
    """
    Returns the last handshake time for any peer, or None if no handshake has occurred.
    """
    try:
        result = subprocess.run(
            ["docker", "exec", "wg-easy", "wg", "show", "all", "latest-handshakes"],
            capture_output=True,
            text=True,
            check=True,
        )
        lines = result.stdout.strip().split("\n")
        if not lines:
            return None
        # Format: "peer_name\tpublic_key\tlatest_handshake"
        timestamps = [
            int(line.split("\t")[2]) for line in lines if len(line.split("\t")) > 1
        ]

        if len(timestamps) == 0:
            print("No active WireGuard connections found")
            return None

        # The output of "wg show all latest-handshakes" is a list of unixtimestamps.
        # We just need the most recent one.
        latest_handshake = max(timestamps)

        return datetime.datetime.fromtimestamp(latest_handshake)

    except (subprocess.CalledProcessError, FileNotFoundError):
        # Handle cases where the command fails or 'wg' is not found.
        return None


def main():
    """
    Monitors WireGuard traffic and shuts down the instance if it's idle.
    """
    while True:
        last_handshake_time = get_last_handshake_time()

        if last_handshake_time:
            idle_time = datetime.datetime.now() - last_handshake_time
            print(f"Last handshake was {idle_time.seconds // 60} minutes ago.")

            if idle_time.seconds > MAX_IDLE_MINUTES * 60:
                print(f"No traffic for over {MAX_IDLE_MINUTES} minutes. Shutting down.")
                subprocess.run(["sudo", "shutdown", "-h", "now"])
                break
        else:
            # If there are no peers, we should wait for a while and then shutdown
            print("No active WireGuard peers. Shutting down in 15 minutes.")
            time.sleep(MAX_IDLE_MINUTES * 60)
            if not get_last_handshake_time():
                subprocess.run(["sudo", "shutdown", "-h", "now"])
                break

        time.sleep(60)


if __name__ == "__main__":
    main()
