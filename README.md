# AllFinder

**Advanced autonomous subdomain enumeration and asset intelligence for authorized security assessments.**

AllFinder combines passive discovery, optional active DNS enumeration, live HTTP probing, takeover-oriented CNAME checks, and Markdown reporting into a single Bash workflow.

> [!IMPORTANT]
> Use AllFinder only against domains you own or have explicit written permission to assess. Active brute-forcing, HTTP probing, and third-party reconnaissance can generate traffic and may trigger alerts or rate limits. Review the script before use and keep testing within the approved scope.

## What it does

AllFinder runs five phases:

1. **Passive subdomain harvesting** — collects results from Subfinder, Assetfinder, and Findomain, then deduplicates them.
2. **Optional active DNS enumeration** — runs Gobuster or Puredns when a wordlist is supplied.
3. **Live host probing** — uses httpx when available to collect status codes, titles, redirects, content lengths, and detected technologies.
4. **Takeover-oriented analysis** — uses Subzy when available, or a fallback that records CNAME mappings.
5. **Report generation** — creates a summary and structured result files for follow-up review.

## Requirements

AllFinder is a Bash script that uses the following standard tools:

- `bash`
- `curl` or `wget`-compatible network access for the external recon tools
- `sort`, `awk`, `wc`, and `cat`

The script automatically adapts when optional tools are absent, but installing the tools below provides the full workflow:

- [Subfinder](https://github.com/projectdiscovery/subfinder)
- [Assetfinder](https://github.com/tomnomnom/assetfinder)
- [Findomain](https://github.com/findomain/findomain)
- [Gobuster](https://github.com/OJ/gobuster) or [Puredns](https://github.com/d3mondev/puredns)
- [httpx](https://github.com/projectdiscovery/httpx)
- [Subzy](https://github.com/PentestPad/subzy)
- `dig` for the fallback CNAME mapping pass

Tool availability is checked at runtime; missing integrations are skipped or replaced with the script's fallback behavior.

## Installation

```bash
git clone https://github.com/dntaskmehow/AllFinder.git
cd AllFinder
chmod +x allfinder.sh
```

## Usage

```bash
./allfinder.sh -d example.com
```

Add active DNS brute-forcing with a wordlist:

```bash
./allfinder.sh -d example.com -w /path/to/subdomains.txt
```

Route supported HTTP probing through a proxy:

```bash
./allfinder.sh -d example.com -p 127.0.0.1:8080
```

Write results to a custom directory:

```bash
./allfinder.sh -d example.com -o ./authorized-assessment-results
```

### Options

| Option | Description |
|---|---|
| `-d <domain>` | Target root domain; required |
| `-w <wordlist>` | Optional wordlist for active DNS brute-forcing |
| `-p <proxy>` | Optional HTTP proxy address passed to supported tools |
| `-o <directory>` | Optional custom output directory |
| `-h` | Show usage information |

## Generated artifacts

By default, AllFinder creates `AllFinder_Results_<domain>/` and writes:

- `passive_unique.txt` — deduplicated passive subdomain candidates
- `all_unfiltered_subdomains.txt` — combined passive and optional active candidates
- `live_hosts_clean.txt` — hosts or URLs considered live by the selected probe path
- `live_hosts_detailed.txt` — httpx status, technology, title, redirect, and length output
- `takeovers.json` — Subzy takeover-oriented results when Subzy is installed
- `cname_mappings.txt` — CNAME fallback mappings when Subzy is unavailable
- `recon_summary.md` — target and artifact summary

## Responsible use

- Confirm written authorization and the exact domain scope before running.
- Review and test the script's request behavior in a controlled environment.
- Add an explicit wordlist only when active enumeration is approved.
- Review generated data before distribution; DNS and HTTP reconnaissance may expose sensitive asset information.
- Stop or adjust the run if infrastructure begins returning errors, throttling requests, or behaving unexpectedly.

## Project status

AllFinder is an early-stage Bash reconnaissance workflow. Optional external tools determine the completeness of each phase, and discovery results should be reviewed in context rather than treated as definitive findings.

## Source

- [`allfinder.sh`](allfinder.sh)
- [Repository](https://github.com/dntaskmehow/AllFinder)
- [Issues](https://github.com/dntaskmehow/AllFinder/issues)
