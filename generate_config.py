"""
Generate WireGuard config file.

This invlovles ssh'ing onto the WireGuard machine, waiting for cloud-init to finish
setting up the box, then retrieving the Server's publick key. This can take from 1-10minutes,
and sometimes the admin user isn't created straight away, and the first ssh attempt may fail.

But just keep trying.
"""
import os
import json
import argparse
from pathlib import Path
import subprocess
import textwrap

ROOT_DIR = os.path.dirname(__file__)


def main():
    parser = argparse.ArgumentParser("Generate WireGuard config")
    parser.add_argument(
        "--ssh_key",
        default=Path(os.environ["HOMEPATH"], ".ssh", "cloud").absolute(),
        help="path to SSH private key, used to connect to WG Server",
    )

    if os.name == "nt":
        default_key_folder = ROOT_DIR
    else:
        default_key_folder = "/etc/wireguard/"
    parser.add_argument(
        "--private-key-path",
        "-pri",
        dest="key_pri",
        default=os.path.join(default_key_folder, "private.key"),
        help="Path to wg client private key",
    )
    parser.add_argument(
        "--preshared-key-path",
        "-psk",
        dest="key_psk",
        default=os.path.join(default_key_folder, "psk.key"),
        help="Path to wg client preshared key",
    )

    args = parser.parse_args()
    with open(args.key_pri, "r") as f:
        cli_key_pri = f.read()
    with open(args.key_psk, "r") as f:
        key_psk = f.read()

    # First, We need the remote server's IP address and username
    cmd = ["terraform", "output", "-json"]
    proc = subprocess.run(cmd, check=True, capture_output=True)
    output = json.loads(proc.stdout.decode())
    # Some outputs return a list of a IP address
    srv_ip = output["ip_address"]["value"]
    if type(srv_ip) == list:
        srv_ip = output["ip_address"]["value"][0]
    srv_username = output["username"]["value"]
    ssh_port = output["ssh_port"]["value"]
    wg_port = output["wg_port"]["value"]

    # Use SSH to get the Server's public key
    ssh_identity = list()
    if args.ssh_key is not None:
        ssh_identity = ["-i", args.ssh_key]
    cmd = [
        "ssh",
        "-oStrictHostKeyChecking=no",
        *ssh_identity,
        f"{srv_username}@{srv_ip}",
        "-p",
        str(ssh_port),
        "/opt/get_wireguard_status",
    ]
    proc = subprocess.run(cmd, check=True, capture_output=True)
    srv_pubkey = proc.stdout.decode().strip()

    # Now we can generate and print the config file
    config = textwrap.dedent(
        f"""\
        [Interface]
        PrivateKey = {cli_key_pri}
        Address = 10.77.67.2
        DNS = 1.1.1.1

        [Peer]
        PublicKey = {srv_pubkey}
        PresharedKey = {key_psk}
        AllowedIPs = 0.0.0.0/0
        Endpoint = {srv_ip}:{wg_port}
        PersistentKeepalive = 25\
        """
    )
    print(config)


if __name__ == "__main__":
    main()
