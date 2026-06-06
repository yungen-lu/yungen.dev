---
title: Reflections on Week 2 at RV Tech
lastmod: 2026-06-06 14:44:08-07:00
date: 2026-05-30T15:54:09-0700
draft: false
publishDate: 2026-05-31
---

Week 2 of my internship, and a lot of firsts this week: my first MR (doc improvements), my first design document, and the first meeting I ran to discuss that design doc and collect feedback.

## Wearing the PM hat

Our team has no Product Manager. As I wrote last week, we have external customers (car owners) and internal ones (our own engineers), and almost every feature request comes from the internal side as other teams change what they need. With no PM to turn those needs into specs, every engineer has to do it themselves.

In my previous internship the PM wrote the user persona, the user story, what the UI should look like. All I had to do was implement it. This week I had to do that part myself. Who is going to use this? Which need comes first? What should the mockup look like? It is more work but it is the part I learned the most from, and thankfully we have Claude Design, which makes it easier.

## Don't inherit a design decision you don't understand

Our service already sends event messages to service B through AWS SNS. My new feature also needed to get information to B, so I followed the existing pattern and routed it through SNS too. In the meeting, someone asked a simple question: why does this go through SNS? My only answer was that I saw the current code doing it that way. It turned out I didn't need SNS at all. I didn't even need to send anything to B. I could call service A directly over REST. The engineer who asked then explained why SNS was chosen in the first place, and added that A and B are going to be merged later anyway, so the messaging was not worth worrying about.

The lesson: don't assume an existing design decision is correct and copy it. The people who made it had context I didn't, and sometimes that context has already changed.

A manager from the OTA Updater team noticed my design doc and messaged me a few days later. He wasn't on the team I'd asked for feedback, he was just curious about the feature I was building and how to use it. We had a great conversation.

## AI

Whenever I ask my mentor something, he often says "try asking AI" and opens Claude Code right there. When I run into a problem where I know exactly what to look up, I still do it the old way: to find a function I open the editor and search the name; when a package fails to install I read the file and Google the error. I know AI can hallucinate, so I still trust the data and docs I find online. In my mind I still need some kind of proof to convince me that I got the correct answer.

Part of me holds a pride in solving things the old way. But AI is powerful enough now that you can make it do things you don't understand, and using it in front of people makes me afraid it signals I don't actually understand what I'm doing.

I'm still exploring this. I'm really curious how senior engineers use AI to write code (if only I could watch over their shoulder while they work...). I'm going to sit with it and write more next week.

## Match the effort to how the code will be read

From a friend who contributes to the Linux kernel, I learned that when you submit a patch to the Linux kernel, reviewers read it commit by commit, so the order, the message, and the description of each one count. I tried to apply the same effort to my first MR, and in the end I realized that for this kind of MR I really don't need to make everything perfect, because nobody is going to read it commit by commit.

The part I changed will be obsolete after we upgrade the framework, so it is probably not worth the effort on the git descriptions. Perfect commits matter when you're changing complex logic that someone has to understand piece by piece.

## Knowing your team

What still bothers me is how distant I feel from my own teammates. Most of them work remote, and I barely interact with them. What I noticed is that I interact more with engineers on a different team, mainly because they sit near me. Physical proximity bonds people fast. Bonding over Zoom is much harder.

As an introvert, reaching out to people I don't know is hard (or maybe that's an excuse). It's easier when the interaction is forced in some way: someone sits next to me, we're in the same room for a meeting, or somebody sets up a 1:1. Remote work removes all of those forced moments, so with my own team there's nothing pushing us together.