# Stock & costing: put it online with GitHub and Supabase

When you finish, you'll have:

- a web address your whole team can open on phones, tablets and computers
- a sign-in for each person, so every entry shows who made it
- live sync: a sale on the counter tablet appears on the office computer right away
- offline use: once installed and signed in, the app opens and records sales, deliveries and counts without internet, then syncs when the connection returns

It takes about 30 minutes. Supabase and GitHub both change their menus from time to time, so a label may read slightly differently than below.

---

## Step 1. Set up the database in Supabase

1. Go to **supabase.com**, sign in, and open your project. If you don't have one yet, click **New project**. Pick **Southeast Asia (Singapore)** as the region, since it's closest to the Philippines. Save the database password somewhere safe.
2. In the left menu, open **SQL Editor**, then click **New query**.
3. Open the file **supabase-setup.sql** from this folder, copy everything in it, paste it into the editor, and click **Run**. You should see "Success". It's safe to run again if you're unsure.
4. Copy two values; you'll need them in Step 2:
   - **Project URL**, which looks like `https://abcdefghijklmnop.supabase.co`. It's on the project home page under **Connect**, or in **Project Settings → Data API**.
   - The **anon public** key, called the **publishable** key on newer projects. It's in **Project Settings → API Keys**.

Never copy the **service_role** or **secret** key. That key bypasses all security and must not go into the app.

## Step 2. Put the app on GitHub

1. On **github.com**, click **New repository**. Name it, for example, `stock-costing`, choose **Public**, and click **Create repository**.
   GitHub's free plan only publishes websites from public repositories. Only the app's code is public. Your business data stays in Supabase behind sign-in.
2. On the new repository's page, click **uploading an existing file**. Drag in **everything** from this folder: `index.html`, `config.js`, `sw.js`, `manifest.webmanifest`, `supabase-setup.sql`, `README.md`, and the `icons` and `vendor` folders. Click **Commit changes**.
   Dragging folders works in Chrome and Edge. If a folder won't drag, open it and drag its files after creating the same folder name.
3. Click **config.js**, then the pencil icon to edit it. Replace the two placeholder values with your Project URL and anon/publishable key from Step 1, keeping the quote marks. Click **Commit changes**.

## Step 3. Turn on the website (GitHub Pages)

1. In the repository, open **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **Deploy from a branch**, choose **main** and **/ (root)**, then click **Save**.
3. Wait a minute or two and refresh. The address appears at the top, for example `https://yourname.github.io/stock-costing/`. That's the address you'll share with your team.

## Step 4. Connect the address to Supabase and lock sign-ups

1. In Supabase, open **Authentication → URL Configuration**. Set **Site URL** to your GitHub Pages address, and add the same address under **Redirect URLs**. This makes password-reset links come back to your app.
2. Open **Authentication → Sign In / Providers**. Keep **Email** turned on, and turn **off** "Allow new users to sign up". This way only people you add can get in.

## Step 5. Create accounts for yourself and your staff

1. In Supabase, open **Authentication → Users → Add user → Create new user**.
2. Enter the email and a password, tick **Auto Confirm User**, and click **Create user**.
3. **Create your own account first**, because the first account becomes the **Owner**. Then create one for each staff member and give them their email and password. They can change their password in the app under **Setup → Your account**.
4. To make someone **view-only**, for example an accountant: open **Table Editor → profiles**, find their row, and change **role** to `viewer`. The options are `owner`, `staff` and `viewer`.

## Step 6. Move your current data across

Do this when you're ready to switch, so nothing gets left behind.

1. In the current version of the app on Claude, go to **Setup → Download backup**. The file includes materials, recipes, stock movements, purchase orders, sales, customers and scheduled orders.
2. Open your new GitHub Pages address and sign in with the owner account.
3. Go to **Setup → Restore from backup**, choose the file, and confirm.
4. From now on, use only the new address. The Claude version and the new one don't sync with each other.

Entries made in the Claude version show the person as "Someone", because the sign-in accounts are new.

## Step 7. Install it on phones and tablets

- **Android (Chrome):** open the address, tap the ⋮ menu, then **Install app** or **Add to Home screen**.
- **iPhone or iPad (Safari):** open the address, tap **Share**, then **Add to Home Screen**.

Sign in once while connected. After that, the app opens from the home screen even without internet.

---

## Good to know

**Working offline.** Everything you record offline is kept on that device and sent automatically when the internet returns; the sync indicator shows how many changes are waiting. Don't sign out while changes are waiting, because signing out clears the device's copy. The app warns you if you try.

**Printing and exports.** PDF slips, forms and reports, plus Excel exports, all work offline, because their libraries are included in the `vendor` folder.

**Backups.** Supabase's free plan doesn't include restorable daily backups. Download a backup from **Setup** every week or so and keep it somewhere safe, such as Google Drive.

**Free plan limits.**
- A Supabase project on the free plan pauses after about a week with no activity. Daily use keeps it awake; if it does pause, click **Restore project** in the dashboard.
- The free database holds 500 MB, which is years of sales for a small business.

**Forgotten passwords.** Supabase's built-in email sending is very limited, so reset emails may not arrive. For reliable reset emails, set up your own email sender in **Authentication → Emails → SMTP settings**; a Gmail app password or a free Brevo account works. Otherwise, delete the user and create them again with a new password. Their past entries will then show as "Someone".

**Updating the app later.** Upload the new `index.html` (and any other changed files) to the repository, replacing the old ones. Devices pick up the new version the next time they open the app online; sometimes it takes closing and reopening twice.

## If something isn't working

- **"Connect your database" screen:** `config.js` still has the placeholders, or a value was pasted with a typo or without quote marks.
- **"That email and password don't match":** the user wasn't created, wasn't auto-confirmed, or the password is different. Check **Authentication → Users**.
- **Changes are refused as "view-only" for everyone:** the setup script didn't finish, so there are no rows in **profiles**. Run `supabase-setup.sql` again. People created before the script ran are added when it runs.
- **Other people's changes only appear after reopening:** live updates aren't on. Run the setup script again, or check **Database → Publications** that the `docs` table is included in `supabase_realtime`.
- **The address shows "404":** GitHub Pages is still publishing (wait two minutes), or `index.html` isn't at the top level of the repository.
