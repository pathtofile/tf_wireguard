"""
Generate WireGuard config file.

This invlovles ssh'ing onto the WireGuard machine, waiting for cloud-init to finish
setting up the box, then retrieving the Server's publick key. This can take from 1-10minutes,
and sometimes the admin user isn't created straight away, and the first ssh attempt may fail.

But just keep trying.
"""
import json
import argparse
from pathlib import Path
import subprocess
import textwrap

ROOT_DIR = Path(__file__).parent


def main():
    parser = argparse.ArgumentParser("Generate WireGuard config")
    parser.add_argument(
        "--ssh-key",
        "-s",
        dest="ssh_key",
        default=Path(ROOT_DIR, "id_tf_wireguard"),
        help="path to SSH private key, used to connect to WG Server, default is 'id_tf_wireguard' in current directory",
    )

    parser.add_argument(
        "--private-key-path",
        "-pri",
        dest="key_pri",
        default=Path(ROOT_DIR, "client_private.key"),
        help="Path to wg client private key",
    )
    parser.add_argument(
        "--preshared-key-path",
        "-psk",
        dest="key_psk",
        default=Path(ROOT_DIR, "psk.key"),
        help="Path to wg client preshared key",
    )
    parser.add_argument(
        "--ddns-hostname",
        "-d",
        dest="ddns_hostname",
        help="Use this hostname instead of the IP in the config file. Useful when using dynamic DNS.",
    )
    parser.add_argument(
        "--no-dns",
        "-n",
        dest="no_dns",
        action="store_true",
        help="If set, do not add DNS line to config",
    )

    args = parser.parse_args()
    with open(args.key_pri, "r") as f:
        cli_key_pri = f.read().strip()
    with open(args.key_psk, "r") as f:
        key_psk = f.read().strip()

    # First, We need the remote server's IP address and username
    cmd = ["terraform", "output", "-json"]
    proc = subprocess.run(cmd, check=True, capture_output=True)
    output = json.loads(proc.stdout.decode())
    # Some outputs return a list of a IP address
    srv_ip = output["ip_address"]["value"]
    if type(srv_ip) is list:
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
    wg_host = srv_ip
    if args.ddns_hostname is not None:
        wg_host = args.ddns_hostname
    dns_line = "DNS = 8.8.8.8\n"
    if args.no_dns:
        dns_line = ""

    config = textwrap.dedent(
        f"""\
        [Interface]
        PrivateKey = {cli_key_pri}
        Address = 10.77.67.2
        {dns_line}
        [Peer]
        PublicKey = {srv_pubkey}
        PresharedKey = {key_psk}
        AllowedIPs = 0.0.0.0/0, ::/0
        Endpoint = {wg_host}:{wg_port}
        PersistentKeepalive = 25"""
    )
    print(config)


if __name__ == "__main__":
    main()
