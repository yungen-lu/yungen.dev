---
title: Writing with AI
lastmod: 2026-07-07 01:52:52-07:00
date: 2026-07-06T23:59:54-0700
draft: false
publishDate: 2026-07-05
---

![](r0000055.jpg)

I wrote a lot of things recently: my second design document, my own midterm intern evaluation, and a bunch of follow-up Jira tickets from my previous project. Luckily, I stumbled upon these two wonderful blog posts [How to Write an Effective Software Design Document](https://refactoringenglish.com/excerpts/write-an-effective-design-doc/) and [How to Get Meaningful Feedback on Your Design Document](https://refactoringenglish.com/excerpts/useful-feedback-on-design-docs/)

My typical workflow is: I first give AI my end goal and some context, then I ask AI to ask me questions. After we both agree on what we're going to write, I then instruct AI to draft it. Then I revise it paragraph by paragraph, sentence by sentence. Sometimes I might even rewrite the whole paragraph by myself.

Looking at this you might ask: if you are gonna rewrite it, why bother letting AI write it in the first place? I like to think of it this way: you have a bunch of ideas, and tons of ways to connect them. For each idea, each paragraph, each sentence, there are many different ways to "write" it. This [overchoice](https://en.wikipedia.org/wiki/Overchoice) leaves you unsure where to start, or what to write. So by letting AI write the draft, you let it eliminate some of your choices, which makes it easier for you to edit.

But this only works for technical documents, where the main goal is to help readers understand a concept, a design, or a task, so a rough draft saves me time and effort. For a blog post, where the writing is about expressing yourself, letting AI draft it just gives you another choice, and often that choice is a bad one.

AI's writing is far from good ... From a recent podcast between Dwarkesh Patel and Grant Sanderson (3Blue1Brown):

> [!quote] It is incredibly interesting, because a common concern people have about AIs is this [entropy collapse](https://arxiv.org/html/2512.12381v1) where they all think the same way, because they're trained in similar ways. This is why they're bad at writing. They go down the same path and have similar patterns of speaking and so forth.
> — Dwarkesh Patel

> [!quote] This is where autoregression is a very weird way to generate things. When you're writing, you sort of know that in order for it to be good, you have to have an element of the unpredictable. It's not just increasing the temperature in your mind. It's knowing exactly the correct point when you want to make an unpredictable move, and that that's going to be what's more insightful.
> — Grant Sanderson

That's why I don't really let AI draft my blog posts. I only use it to fix my grammar and improve my writing (hopefully...). I tried to let it write the first draft several times, but in the end I always find myself rewriting most of it...

By letting AI ask you questions, you will soon find out: a) how bad you are at expressing your ideas, b) how bad AI is at understanding your ideas, c) there will always be edge cases you never think about when writing the prompt. Letting AI ask questions isn't something new. I first discovered this method through this article [Turning the Tables on AI](https://ia.net/topics/turning-the-tables-on-ai), and people have been using [this method](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md) for development too. If you don't "force" yourself to really think about what you want to write, you will soon find yourself in [cognitive surrender](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6097646), accepting everything AI writes for you.

> [!quote] Once men turned their thinking over to machines in the hope that this would set them free. But that only permitted other men with machines to enslave them. — Frank Herbert, _Dune_