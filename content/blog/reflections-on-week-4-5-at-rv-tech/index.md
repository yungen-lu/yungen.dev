---
title: Reflections on Week 4 & 5 at RV Tech
lastmod: 2026-06-24 01:25:03-07:00
date: 2026-06-19T12:42:06-0700
draft: false
publishDate: 2026-06-23
---

Over the past two weeks I spent time refining my own AI workflow, and I'd like to share some of my thoughts about it.

## Using AI is an engineering problem

> [!quote] Programming is the immediate act of producing code. Software engineering is the set of policies, practices, and tools that are necessary to make that code useful for as long as it needs to be used, and to allow collaboration across a team.
> — Titus Winters, *Software Engineering at Google*

If software engineering is programming integrated over time, then agentic engineering is markdown files and harness tools integrated over time. Getting AI to do useful work is not a one-time setup. It is something you build and iterate on.

## Treat your workflow as a project

A workflow is a project, and like any project it changes as your needs change. When I built mine, I started by writing down what I wanted an ideal workflow to look like, and talked it through with Claude Code. I used that first version for a while and found the parts that didn't work. Then I went back, described the problem, and let Claude Code propose a change. I reviewed it, and once I approved it, I asked for a migration plan.

That last step matters. Because the workflow is a project, you have to think about how it gets updated, migrated, and reverted, the same as any codebase. The other thing that helped was treating changes like code: ask the AI to test them, or test them yourself, then give feedback and let it improve. Requirements, versioning, migration, testing.

## Context, Context, Context

When setting up the workflow, one of the first questions is: what should I put in the context? The context window is limited, so you can't just dump everything in. And sometimes when you give the LLM more information than it needs, it overthinks things. So what should I disclose to it? The question becomes one of context engineering: what should I give the LLM so it returns the most engineering value. Note that I didn't say maximum code quality, I said engineering value.

For example, when I am working on feature A and change something that might affect feature B, I would want the AI to remind me to update the related Jira issue or design doc, and even suggest who to ask when I run into a problem. And when I later work on feature B, I would want the AI to already know that feature A affected it, and take that into account while writing the code.

There is also a problem I think most engineers will hit: at some point you reach the context limit before you finish the feature or the fix. How do you compress or cut the information from past interactions without the AI forgetting the details that matter?

## No workflow fits everyone

Obviously, there is no workflow, tool, or method that fits everyone. Every company has its own culture, every team has its own way of doing things, and most importantly, everyone interacts with AI in their own way.