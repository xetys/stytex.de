---
layout: post
title: "GIT vs Subversion"
date: 2015-07-08 18:00:00 +0100
comments: true
categories: 
 - development
 - devops
 - system administration
---

For a quite long time my opinion in this question was: Subversion. Maybe this has todo with "oldschool" :)

But no, that wasn't only that. It is the simplicity of subversion. All started with the task "Choose your weapon!" when I had to setup a versioning system for future projects. I had used subversion before, so I was similar with it's commands, and even newbie friendly server administration. I spent some time researching, how a setup of a git hoster. Compared to the same task with subversion, my decision was clear so far.



But let's go through the facts!



## Subversion

Subversion is a centralized versioning system, what makes thinks really easy at the beginning. Of course, everything about trunk, brachning and tagging, was foundet in this system. But you are free just to use Subversion as a pure versioning system. This means, you are not managing a standard layout as trunk/, branches/ and tags/. But when you do, you have all the benefits of branching and merging. 

But the greatest benefit of centralization is, it's simple. You have got one central node, or host, which keeps your repository. Every commit is going through it. The first time you notice this, is when you setup a Subersion host. There at least 2 steps: installing subversion, and doing a svnserve. Okay, you can also make some init scripts and so on. But this is candy :)

More on benefits: not only a repository can act as an repository, the subdirectories also can. For example, you can create a "project", which has no standard layout, but its subdirectories have. So you are fully free to design your own structure, by keeping the subversion theory of trunk-branch-tag.

Now to the disadvantages, you will have to think about backups. Subversion gives no solutions for that. More that this, each checkout of your repo is not a complete replica of the repo. All the logs and commits are saved on host.



And back again, it has a free design. I managed it to use subversion a long time, without having any idea what branches are. With great power comes great responsibility.



## GIT

One things I hated right at the beginning is that git is beeing hyped that strong all the time. Git is king, git is best, fuck subversion, it's for noobs :) The most thing I dislike, that no one can tell me WHY git is better then subversion, but it is better? Maybe it has something to do with git is made by Linus Torwalds, so it just must be better by definition.

Now seriously, when you work on subversion with strict standard layouts, doing branches and tags, git brings this right out of the box. In git, you just can't really go beside branches. When you init a repo, you are already in "master" branch, which is the trunk from subversion. The good is, branching and tagging is a core git feature, which is not realized with directories. For example: when you just create a branches and a tags directory in subversion, there is no difference between them. So when you just tag, you still can commit into this directory or even merge it back to trunk. You can avoid it by your own, or justify more options. In git, this is standard.

But let's talk about gits distributive behaviour. This is mighty, but only if you know the benefits of it. This make your life a bit harder, because every git repo is by it's own in nature, independent of something else. But this also means, every clone is a full replica, including commits and history. Looking for a way to make a backup of your repo quickly? Just clone it somewhere. You will be able reproduce the repo on host, if it will lost. When you are looking for remote repositories like in subversion, you will need a git host. But when you commit, you commit inside your own repository. To make a subversion style commit, you "push". This sounds confusing, but make things more structured. I prefer to make commits more often, and using the messages as notes, what I had done recently. Using subversion, I know, every commit goes to the host, which is open for all. In git, I say, when all my commit are going to the host. "A" host? No, git is distributed, so you can also have several hosts :) You see, you are free to do more, if you know how you can profit from it.

One more thing: I really really hate subversion set props for managing ignore files. I was crying of happiness, when I saw how gitignore works...



## When things get critically

Why do we need all this? We need collaboration tools for modern software development. That's why developpers are sometimes looking for the right answer: git or subversion?

So it's time to talk about, what you really need.

You will need:

- a versioning system
- a host for your VCS, what is simply accessible from all common plattforms
- a deployment system, which is not to complicated
- Starting from a bare VCS, you will have a long and hard way to go. In my past I had managed such systems, but I was the only one, who was able to use it in critical situations as - -- reverting releases, when they failed.


I have changed my mind from subversion to git, when I found Meat!

Meat comes with a mighty collaboration system, as you know it from github. It actually is working similar to github, but adds release scenarios. Finally I got in touch with git, after studying how to use subversion correctly. And a lot of thinks, I had to manage manually in subversion, was working out of the box in git. Like branching, read only tags, complex hosting nodes. And even in the point of "how should I backup my files", I am very chilled with git.



Both systems are mighty, but now I can say: git brings all that things you need from a software developer oriented versioning system.



Together with Meat!, git is my new best friend :)