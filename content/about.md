---
title: About
description: About
date: 2024-12-26T12:40:03+08:00
lastmod: 2025-07-13T00:09:20+08:00
draft: false
menu: main
weight: 2
---

## Yung-En Lu

### Education

**Master of Computer Science** @ Rice University
Aug 2025 – Dec 2026

**Master of Science in Computer Science** @ National Yang Ming Chiao Tung University
Sep 2024 – Jun 2025

**Bachelor of Science in Computer Science and Information Engineering** @ National Cheng Kung University
Sep 2021 – Jun 2024

### Work Experience

**Software Engineer Intern** @ [MaiAgent](https://maiagent.ai) (formerly Playma)
Feb 2025 – Present

- Developed new **RESTful APIs** and features with **Django** while streamlining DevOps automation for the MaiAgent AI platform, gaining 6 new partners, including CTBC Bank, MSI, and HPE
- Reduced CNAME vanity domain setup time by over **80%** for our the MaiAgent AI platform by developing a backend service that automates **CDN** provisioning and SSL/TLS certificate management on **AWS CloudFront**
- Cut production deployment time for 12 **AWS EC2** instances from 30 to under 5 minutes by utilizing **Ansible**
- Enabled air-gapped **on-premises** deployments for **3 banks** by automating setup with Ansible, reducing deployment time from hours to minutes across diverse OS (Ubuntu/RHEL/CentOS) and VM topologies
- Accelerated Ansible testing by 50% across inventories by building a CI pipeline with **Molecule** and **GitHub Actions**
- Integrated HeyGen and D-ID services into the webchat to create talking avatars, presented to **10+** clients

**Software Engineer Intern** @ [Trend Micro](https://www.trendmicro.com/)
Jul 2023 – Aug 2023

- Worked on the Web Reputation Service team, contributing to the migration of the Web Classify Server (WCS), a legacy service handling **700 million** daily classification requests
- Cut infrastructure costs by **10%** by migrating the WCS legacy service from VMs to **Kubernetes**
- Reduced WCS deployment time by **20%** by building CI/CD pipelines with **GitHub Actions** and **Helm charts**
- Improved service reliability by implementing a **Prometheus** exporter that monitored WCS pattern file updates across **200+** nodes, enabling real-time detection of outdated nodes and reducing reliance on user reports
- Reduced desynchronization errors from ∼3 per week to **nearly zero** by redesigning the WCS pattern file sync process to address issues with **AWS S3** Cross-Region Replication and network instability

**Software Engineer Intern** @ [AInimal](https://official.ainimal.io/)
Jan 2022 – Jun 2023

- Led the migration of a monolithic backend into 4 **Go** and **Node.js** microservices, designing **gRPC** APIs for inter-service communication to build a more fault-tolerant and scalable system
- Deployed backend infrastructure on **GKE** with Cloud SQL and Cloud Storage using **Terraform**, improving scalability and reducing overall service downtime by **12%**
- Scaled chat service to handle **5,000+** concurrent users by adopting Go, **MongoDB** and **Google Cloud Pub/Sub**
- Improved notification responsiveness by **20%** by developing the notification service in Go and redesigning the click-through flow in **React Native**
- Built test suites with **90%+** coverage and automated testing/build/deployment pipelines using **GitLab CI/CD**, reducing regressions by **16%** and release time from hours to minutes

**Software Engineer Intern** @ [Intelligent Mobile Service Lab](https://www.imslab.org/)
Jun 2022 – Jan 2023

- Refactored and optimized an online judge website with **Vue**/Vuetify, improving responsiveness and usability for **200+** students
- Optimized core components with asynchronous loading, reducing average page load times by **~20%**

### Research Experience

**Research Assistant** @ Software Engineering and Intelligent Test Automation Lab
Oct 2021 – Oct 2024

- Developed a prompt optimization method for large language models (LLMs) using pairwise feedback, reducing annotation effort by **50%** while maintaining performance
- Implemented a new screen recording feature for [Rapi](https://www.rapi.dev) (web application testing software), enabling local and remote browser recording during test cases which reduced debugging and bug reproduction time by **50%**
- Built an auto-scalable tool for a Kubernetes-based Selenium Grid, enabling reliable video capture across large-scale parallel test suites

**Remote Research Assistant** @ [XR for Intelligent Medicine Lab](https://xrlab.csie.ncu.edu.tw/)
Dec 2023 – Sep 2024

- Developed a customizable LLM-based virtual therapist using **LangChain**, retrieval-augmented generation (RAG), and prompt engineering, improving personalized mental health support
- Built a pipeline to preprocess and embed data from **3** mental health datasets of varying sizes (∼50k docs), storing embeddings in **Qdrant** for RAG context retrieval
- Surveyed and experimented with different evaluation methods to assess the effectiveness of an LLM-based virtual therapist in providing emotional support

### Projects

[DBonK8s](https://github.com/yungen-lu/DBonK8s)  |  Go, Kubernetes, Terraform, GCP, Kustomize

A chatbot that gives users and admins an easy way to manage databases for development and testing

- Built a chatbot to simplify database provisioning (MySQL, PostgreSQL, Redis, MongoDB) for development and testing environments
- Utilized Kubernetes API, namespace and RBAC to create secure, multi-tenant resource management

[Yungen's blog](https://yungen.dev/) |  Hugo, GitHub Actions

My personal website that automatically syncs with my Obsidian notes through GitHub Actions
- Developed a personal website that automatically syncs with Obsidian notes
- Implemented a CI/CD pipeline with GitHub Actions for content sync and deployed using Cloudflare Pages

[bookmark](https://bookmark.yungen.dev)  |  TypeScript, Node.js, Hugo, GitHub Actions

My personal bookmark website that automatically syncs with my Notion notes through GitHub Actions

- Utilized Notion SDK to export Markdown files from Notion notes and Hugo to generate a static site
- Automated the generation, updating, and deployment processes using GitHub Actions, eliminating the need for manual reconfiguration and deployment, resulting in a 30-minute time savings per edit

### Publications

- **Yung-En Lu** and Shin-Jie Lee, “Prompt Optimization with Human Annotations Using Pairwise Comparison,” in *Proceedings of the IEEE International Conference on e-Business Engineering (ICEBE)*, 2024, pp. 15–22, doi: 10.1109/ICEBE62490.2024.00012.
- Chun-Chuan Chen, Meng-Chang Tsai, Eric Hsiao-Kuang Wu, Shao-Rong Sheng, Jia-Jeng Lee, **Yung-En Lu**, Shih-Ching Yeh, “Fusion model using resting neurophysiological data to help mass screening of methamphetamine use disorder,” *IEEE Journal of Translational Engineering in Health and Medicine*, doi: 10.1109/JTEHM.2024.3522356.

### Activities

- **Teaching Assistant** | Program Design II, Feb 2024 – Jun 2024
- **Core Team Member** | Google Developer Student Club, Sep 2022 – Jun 2023
- **Teaching Assistant** | Program Design I, Sep 2022 – Jan 2023
