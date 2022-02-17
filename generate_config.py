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
import subprocess
import textwrap


def main():
    parser = argparse.ArgumentParser("Generate WireGuard config")
    parser.add_argument("cloud_provider",
                        help="Cloud provider",
                        choices=["aws", "azure", "digitalocean"])

    parser.add_argument(
        "ssh_key",
        help="path to SSH private key, used to connect to WG Server")

    key_folder = ""
    if os.name != "nt":
        key_folder = "/etc/wireguard/"
    parser.add_argument("--private-key-path",
                        "-pri",
                        dest="key_pri",
                        default=key_folder + "private.key",
                        help="Path to wg client private key")
    parser.add_argument("--preshared-key-path",
                        "-psk",
                        dest="key_psk",
                        default=key_folder + "psk.key",
                        help="Path to wg client preshared key")

    args = parser.parse_args()
    with open(args.key_pri, "r") as f:
        cli_key_pri = f.read()
    with open(args.key_psk, "r") as f:
        key_psk = f.read()

    provider_path = os.path.join(os.path.dirname(__file__), args.cloud_provider)

    # First, We need the remote server's IP address and username
    cmd = ["terraform", f"-chdir={provider_path}", "output", "-json"]
    proc = subprocess.run(cmd, check=True, capture_output=True)
    output = json.loads(proc.stdout.decode())
    srv_ip = output["ip_address"]["value"]
    srv_username = output["username"]["value"]
    ssh_port = output["ssh_port"]["value"]

    # Use SSH to get the Server's public key
    ssh_identity = list()
    if args.ssh_key is not None:
        ssh_identity = ["-i", args.ssh_key]
    cmd = [
        "ssh", "-oStrictHostKeyChecking=no", *ssh_identity,
        f"{srv_username}@{srv_ip}", "-p",
        str(ssh_port),
        "sudo bash -c 'cloud-init status --wait >/dev/null && wg >/dev/null && cat /etc/wireguard/public.key'"
    ]
    proc = subprocess.run(cmd, check=True, capture_output=True)
    srv_pubkey = proc.stdout.decode().strip()

    # Now we can generate and print the config file
    config = textwrap.dedent(f"""\
        [Interface]
        PrivateKey = {cli_key_pri}
        Address = 10.77.67.2
        DNS = 1.1.1.1

        [Peer]
        PublicKey = {srv_pubkey}
        PresharedKey = {key_psk}
        AllowedIPs = 0.0.0.0/0
        Endpoint = {srv_ip}:51820
        PersistentKeepalive = 25\
        """)
    print(config)


if __name__ == "__main__":
    main()
