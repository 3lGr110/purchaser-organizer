# Capture every Apple Pay purchase automatically

iOS 17+ Shortcuts has a **Transaction** trigger that fires when you tap a Wallet card.

1. **Shortcuts** → **Automation** → **+** → **Transaction**.
2. Select **all cards**, leave all categories on, choose **Run Immediately** → **Next**.
3. **New Blank Automation** → **Add Action** → search **Log Purchase** (Purchaser Organizer).
4. Map the variables (tap each field → *Shortcut Input*):
   - **Merchant** → *Merchant*
   - **Amount** → *Amount*
   - **Card or Pass** → *Card or Pass* (optional)
5. **Done**. Make an Apple Pay purchase — a banner like
   “Logged $23.10 at Kroger · Groceries” confirms it.

**Notes**
- If you paid with the phone locked, the purchase waits in an encrypted inbox and is
  imported next time you unlock the app.
- Some online/in-app Apple Pay payments don't trigger the automation (iOS limitation).
  Use FinanceKit (Apple Card) or manual entry for those.
