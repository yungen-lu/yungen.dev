---
title: Automating daily life with Claude Code
lastmod: 2026-05-16 23:02:32-07:00
date: 2026-05-16T15:58:17-0700
draft: false
publishDate: 2026-05-16
---

Recently I stumbled upon this [youtube video](https://youtu.be/aghRgs7KoyI) talking about using AI to increase productivity. One thing that inspired me was that he was using Claude Code to organize emails, news, etc. I like this idea of having AI organize things for you, so I started mimicking his setup.

## Writing a /daily skill

I started by connecting my email accounts to Claude using a connector and created a skill `/daily` so that every time I invoke this skill it will mark/flag emails that are important and archive/trash emails that are not. After Claude Code organizes my emails, it generates a daily note in my Obsidian vault and writes the summary inside the note so that I can easily know what Claude Code has done. 

```md
# Daily Brief, <Weekday, Month DD YYYY>

## 🤖 Overnight triage
Archived: N (work N, school N, outlook N)
Starred/flagged: N
Drafts created: N, review before sending
Todos created: N, appear in Things 3 Inbox after next sync
```

It is fun to see Claude Code organize your emails automatically, but to be honest it is actually not that useful. You could basically do this yourself, maybe even faster. So I decided to let this skill do more things.

I use Things 3 as my todo app, so I let Claude automatically create todos based on my email. I also created `/daily evening`, which reads through my todo list and organizes/triages it. As the rules got more involved I had to spell them out explicitly, otherwise Claude would happily archive something it shouldn't or draft replies to bots:

```md
- Archive: obvious notifications only (shipping, password-changed
  confirmations, order receipts, build-passed, automated brand promos).
- Star/flag: real people, deadline-bearing items, account warnings
  from real domains. Always star, never archive, never trash.
- Draft reply: only when the sender is a real person AND the right
  response is high-confidence. Drafts sit in the drafts folder
  until sent, so they are reversible.
- Todo: when an email contains a clear actionable task that won't be
  resolved by a quick reply. Cap at 5 per run.
- Leave unread: everything ambiguous. The brief surfaces it.
```

Furthermore, I connected it with the Readwise MCP (Readwise is where I save articles for later reading) and Anki MCP to notify me if I have unread articles or cards to do.

The whole automation works well, but after using it for a while I realized that the hardest part for me is having to manually type `/daily` in my terminal. Sometimes I just forget to type it, and sometimes waiting for it to finish organizing feels so dumb because I could just open my email client and go through it myself while waiting.

## Moving it to Claude routines

So I did a little bit of research myself and found that you could use `/loop` or [Claude routines](https://code.claude.com/docs/en/routines) to run a prompt automatically. `/loop` was not an option for me because my laptop needs to be awake, so I chose to use routines.

Unlike running the skill on your computer, routines run the prompt in the cloud. The biggest issue is: how do we manage auth? Most MCPs that use OAuth will prompt you to open a web page in your browser, then you enter your credentials and it will automatically handle the rest. But in the cloud you can't do this, because every time it runs in a clean environment.

My solution for this is to use [Composio](https://composio.dev/) (a service that handles all different kind of tools and exposes them through a single SDK) and put the API key in an environment variable. Composio will then automatically manage the auth for you if you set it up beforehand. This way I don't need to put API keys for every service I want to use in the environment variables. I also use the Composio SDK instead of MCP or the CLI, because the tasks and logic I want Claude Code to do are pretty predictable, so I wrote some functions and taught Claude Code when to use them:

```md
- archive_gmail(account_id, thread_ids)
- star_gmail(account_id, thread_ids)
- raft_gmail(account_id, recipient, subject, body, thread_id=...)
- archive_outlook(message_ids)
- flag_outlook(message_ids)
- draft_outlook_reply(message_id, comment)
- create_things_todo(title, body=..., importance="normal"|"high")
```

Also, to make the script able to use the Composio SDK Python package and access my private Obsidian vault on GitHub, I set up a hook that runs a script to set up the Python environment and git clone my vault repo.

One small thing that I noticed when I let Claude Code write the prompt is that I can explicitly tell Claude to fan out the fetch calls. Claude Code will issue multiple Bash calls in a single response

```md
Issue these as separate Bash calls in one message so they run concurrently:
- fetch_calendar(cal_id, today) once per cal_id in CALENDARS.values()
- fetch_unread_gmail(WORK_GMAIL)
- fetch_unread_gmail(SCHOOL_GMAIL)
- fetch_unread_outlook(top=15)
- fetch_reader_unseen_count()
```

## Ref

- [Getting Claude Code to do my emails](https://harper.blog/2025/12/03/claude-code-email-productivity-mcp-agents/)
- [Wrangling my email with Claude Code](https://jlongster.com/wrangling-email-claude-code)


While writing this, I realized that if you have an unused VPS server lying around, you could just install Claude Code on that server and basically do the same thing without worrying much about the auth.... Maybe in the future I will replace all of this using OpenClaw or [NanoClaw](https://nanoclaw.dev/) ...