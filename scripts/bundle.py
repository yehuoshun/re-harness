#!/usr/bin/env python3
"""re-harness 产物打包：CI 端 pack、沙箱端 unpack（同一个文件，同一种实现）。

用途：CI 跑在公开仓库（免费 4vCPU/16G），但产物不能公开 →
打包成 tar.gz 后用 AES-256-CBC + PBKDF2 加密，公开 artifact 里只有密文。

用法：
    python3 bundle.py pack   <源目录> <输出文件.enc>   # 密码取 $RE_BUNDLE_PASS 或 --pass
    python3 bundle.py unpack <密文文件> <目标目录>      # 同上
"""
import argparse
import os
import secrets
import sys
import tarfile
import tempfile

MAGIC = b"REHARNESS1"
KDF_ITER = 200_000


def _derive(password: bytes, salt: bytes) -> tuple[bytes, bytes]:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=48, salt=salt, iterations=KDF_ITER)
    key = kdf.derive(password)
    return key[:32], key[32:]


def pack(src_dir: str, out_file: str, password: str) -> None:
    from cryptography.hazmat.primitives import padding
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        tar_path = tmp.name
    try:
        with tarfile.open(tar_path, "w:gz") as tar:
            for name in sorted(os.listdir(src_dir)):
                tar.add(os.path.join(src_dir, name), arcname=name)
        raw = open(tar_path, "rb").read()
    finally:
        os.unlink(tar_path)

    salt = secrets.token_bytes(8)
    key, iv = _derive(password.encode(), salt)
    padder = padding.PKCS7(128).padder()
    padded = padder.update(raw) + padder.finalize()
    enc = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    blob = enc.update(padded) + enc.finalize()

    with open(out_file, "wb") as f:
        f.write(MAGIC + salt + blob)
    print(f"packed {len(raw)} → {len(blob)} bytes (encrypted): {out_file}")


def unpack(enc_file: str, dest_dir: str, password: str) -> None:
    from cryptography.hazmat.primitives import padding
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    data = open(enc_file, "rb").read()
    if not data.startswith(MAGIC):
        sys.exit("❌ 密文头不对（不是 re-harness bundle）")
    salt, blob = data[len(MAGIC):len(MAGIC) + 8], data[len(MAGIC) + 8:]
    key, iv = _derive(password.encode(), salt)
    dec = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
    padded = dec.update(blob) + dec.finalize()
    unpadder = padding.PKCS7(128).unpadder()
    try:
        raw = unpadder.update(padded) + unpadder.finalize()
    except ValueError:
        sys.exit("❌ 解密失败：密码不对或密文损坏")

    os.makedirs(dest_dir, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        tmp.write(raw)
        tar_path = tmp.name
    try:
        with tarfile.open(tar_path, "r:gz") as tar:
            members = [m for m in tar.getmembers() if not m.name.startswith(("/", ".."))]
            tar.extractall(dest_dir, members=members)
    finally:
        os.unlink(tar_path)
    print(f"unpacked {len(raw)} bytes → {dest_dir}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["pack", "unpack"])
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--pass", dest="password", default=os.environ.get("RE_BUNDLE_PASS", ""))
    a = ap.parse_args()
    if not a.password:
        sys.exit("❌ 未提供密码（$RE_BUNDLE_PASS 或 --pass）")
    (pack if a.action == "pack" else unpack)(a.src, a.dst, a.password)


if __name__ == "__main__":
    main()
