#!/bin/bash

# Benutzer nach dem Ziel fragen
read -p "Bitte geben Sie das Ziel (IP-Adresse oder Hostname) ein: " target

# Abfrage, ob der Tor-Proxy verwendet werden soll
use_tor_proxy=false
read -p "Möchten Sie den Tor-Proxy für den Scan verwenden? (ja/nein): " use_tor
if [[ "$use_tor" == "ja" ]]; then
    use_tor_proxy=true
fi

# Temporäre Datei für die Scan-Ausgabe
output_file=$(mktemp)

# Funktion zum Starten von Tor
start_tor() {
    echo "Starte Tor-Dienst..."
    sudo systemctl start tor
    echo "Warte auf Tor-Dienst..."
    sleep 10
}

# Funktion zum Stoppen von Tor
stop_tor() {
    echo "Stoppe Tor-Dienst..."
    sudo systemctl stop tor
}

# Wenn Tor-Proxy verwendet werden soll, Tor-Dienst starten
if $use_tor_proxy; then
    if ! pgrep -x "tor" > /dev/null; then
        start_tor
    fi
fi

# Nmap-Befehl definieren
nmap_command="nmap --script=http-enum \
                   --script=smb-os-discovery.nse \
                   --script=dns-brute \
                   --script=dns-zone-transfer.nse \
                   --script=ftp-anon \
                   --script=vulners \
                   --script-args mincvss=5.0 \
                   --script=snmp-brute \
                   --script=http-vuln-* \
                   --script=smb-enum-shares \
                   --script=ssl-cert \
                   --script=ssl-enum-ciphers \
                   --script=ssl-known-key \
                   --script=ssh-hostkey \
                   --script=ssh-auth-methods \
                   --script=mysql-vuln-cve2012-2122 \
                   --script=mysql-enum \
                   --script=mysql-databases \
                   --script=mysql-empty-password \
                   --script=smb-vuln-ms17-010 \
                   --script=smb-vuln-cve-2017-7494 \
                   --script=http-headers \
                   --script=http-methods \
                   --script=http-auth \
                   --script=ftp-vsftpd-backdoor \
                   --script=smtp-enum-users \
                   --script=pop3-capabilities \
                   --script=imap-capabilities \
                   --script=banner \
                   --script=nbstat"

# Tor-Proxy hinzufügen, falls ausgewählt
if $use_tor_proxy; then
    nmap_command+=" -sT -Pn --proxy socks4a://127.0.0.1:9050"
fi

# Ziel hinzufügen
nmap_command+=" $target"

# Nmap-Befehl im Hintergrund ausführen und Ausgabe in die temporäre Datei umleiten
$nmap_command -oN $output_file &

# PID des Hintergrundprozesses
nmap_pid=$!

# Funktion zur Anzeige des aktuellen Scan-Status
show_scan_status() {
    while ps -p $nmap_pid > /dev/null 2>&1; do
        clear
        echo "Aktueller Scan-Status:"
        grep -E 'Discovered open port|Host is up|Nmap scan report for' $output_file
        sleep 10
    done
}

# Scan-Status anzeigen
show_scan_status

# Auf Abschluss des Nmap-Scans warten
wait $nmap_pid

# Finale Scan-Ergebnisse anzeigen
clear
echo "Scan abgeschlossen. Ergebnisse:"
cat $output_file

# Temporäre Datei löschen
rm $output_file

# Tor-Dienst stoppen, wenn er gestartet wurde
if $use_tor_proxy; then
    stop_tor
fi
