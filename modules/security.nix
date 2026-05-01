{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # --- Recon / Scanning ---
    nmap
    masscan
    rustscan
    whois
    dnsutils
    whatweb

    # --- Web ---
    ffuf
    gobuster
    feroxbuster
    nikto
    sqlmap
    wfuzz
    dirb

    # --- Exploitation ---
    metasploit

    # --- Password / Hash ---
    john
    hashcat
    thc-hydra
    hashid

    # --- SMB / AD / Windows ---
    enum4linux
    smbmap
    impacket
    netexec # crackmapexec の後継
    responder

    # --- Network ---
    wireshark
    tcpdump
    netcat-gnu
    socat

    # --- Tunneling ---
    chisel

    # --- Wordlists / Resources ---
    seclists
    exploitdb

    # --- Reverse Engineering / Binary ---
    radare2
    ghidra

    # --- Forensics / Stego ---
    binwalk
    foremost
    steghide
  ];
}
