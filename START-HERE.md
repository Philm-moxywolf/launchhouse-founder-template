# Start here

This folder is where your Launchhouse work lives from now on. Claude works in it with you, on your own computer, and it is saved to your own GitHub.

You might be wondering whether this is more setup than the app was. It is less. There is no passphrase and no database. GoHighLevel connects the same way as your other tools, by signing in. You never open a terminal. Everything happens in apps you click through.

## 1. Install three things, once

1. **The Claude desktop app**, from claude.ai/download, signed in to your paid Claude account.
2. **GitHub Desktop**, from desktop.github.com, signed in to your GitHub account. It is how this folder gets onto your computer, and how your work gets backed up.
3. **On a Windows PC only: Git for Windows**, from git-scm.com. Run the installer and press Next on every screen without changing anything. It is what lets Claude save your work and run the Launchhouse checks. A Mac does not need it, though the first time Claude saves your work a Mac may offer to install developer tools: press Install.

## 2. Get this folder onto your computer

1. On GitHub, on your own copy of this folder, press the green **Code** button, then **Open with GitHub Desktop**.
2. In GitHub Desktop, choose where to keep it, for example your Documents folder, and press **Clone**.

## 3. Open it in Claude

1. Open the Claude desktop app and choose **Code**.
2. Choose this folder. Always this same folder.
3. There is nothing to install. Everything Launchhouse needs is already in the folder, so Claude knows the programme the moment it opens.

If Claude does not seem to know about Launchhouse, quit the app and open it again on this same folder.

The folder checks itself every time it opens: git, the settings and the growth-engine folder. It says nothing when all is well, and offers to fix anything it finds.

## 4. Say "start launchhouse"

It checks your computer is ready, asks your name and where you are, and gets the folder ready. About two minutes. If you are starting fresh, it goes straight on to your Founder Brain.

## 5. Bring your work across from the app

If you built anything in the Launchhouse app, bring it over once.

1. In the app, open **Files** and press the button that downloads everything.
2. Drag the downloaded file into this folder.
3. Say **"bring my work across"**.

Your work arrives as it was. It gets tidied for the new setup, and nothing you wrote is rewritten without your yes. After this you do not need the app.

If you are new and have nothing in the app, skip this step. "start launchhouse" already took you to your Founder Brain.

## 6. Connect your tools

Open **Settings** in the Claude app, then **Connectors**, then **Add custom connector**. Name it `HighLevel`, paste `https://services.leadconnectorhq.com/mcp/anthropic/v2` as the URL, and connect it. It signs you in to GoHighLevel and asks you to pick your business's sub-account. If you sell to businesses, do the same for **Apollo** from **Browse connectors**. Then say **"connect my tools"**, and Claude checks everything works.

If signing in does not work on your computer, say "connect my tools" anyway: Claude offers a fallback for GoHighLevel that uses a key from your GoHighLevel account, added by clicking to your computer's own password store, Keychain Access on a Mac or Credential Manager on a Windows PC. Claude never sees it. That fallback only works in the Code tab, not in Cowork.

## Finding your finished work

Once a piece of work is saved, a copy also appears in a "My Launchhouse work" folder on your Desktop. These are copies, updated each time you save in Claude. To change something, ask Claude in your real folder, not the Desktop one, and do not open the Desktop folder in Claude.

## Backing up

Claude saves your work as you go. To send it up to GitHub, open GitHub Desktop and press **Push origin**.

## Running Claude in the cloud

If you ever open this folder in a cloud session rather than on your own computer, Claude says so once: your files and your private lists (people, first lines, DM openers) are not there, and anything saved lands on a side branch rather than your real folder. Engine work belongs on your own computer.

## Using Cowork as well

Cowork can work in this same folder. It is good for dropping in photos, documents and old posts, and for thinking things through. Anything saved into the `growth-engine` folder is seen by both. GoHighLevel connects the same way in Cowork as in Code, but none of the Launchhouse checks run there: your own connector setting for GoHighLevel, set to ask before it posts or sends, is what keeps that in your hands.

## Stuck

Say what is happening in your own words, in Claude. If it is still not right after two tries, post in the Slack channel.
