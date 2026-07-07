---
title: Reflections on Week 6 & 7 at RV Tech
lastmod: 2026-07-07 00:02:03-07:00
date: 2026-07-04T14:49:32-0700
draft: false
publishDate: 2026-07-05
---

![](r0000041.jpg)
## Ownership

I'm happy that one feature I developed was merged last week, and I immediately started thinking about the next step of my project and picking up some follow-up issues. I didn't think about how the code should be deployed to the staging and production environments. The feature spanned multiple repos with dependencies between them, and I totally forgot this part until one deployment went out in the wrong order. I had to ask our devops engineer to run another deployment so that the feature wouldn't break in staging.

Ideally most bugs and issues should be caught while testing in the dev environment, but we often forget that the deployment process, the environment configuration ... and so on might be different in every environment. So verify your work in every environment, not just dev.

## Writings

I also spent a lot of these two weeks writing: a design doc, my midterm intern evaluation, a pile of Jira tickets. That got me thinking about how I use AI to write, and it grew into its own post: [[Writing with AI]].