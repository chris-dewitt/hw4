# HW4 · Azure in one page (for Part 3)

You deploy to Azure **once** for Part 3. It's designed to cost about **$0** and to be safe.
Read this first — especially if you've never used Azure.

## 1. Get Azure for Students (free, no credit card)
- Sign up at **https://azure.microsoft.com/free/students/** with your **UNC email**.
- You get **$100 credit for 12 months** plus many always-free services — **no credit card required**.
- **Do this early** — student verification can take up to a day. Don't wait until the deadline.

## 2. You (almost certainly) can't be charged real money
- Azure for Students keeps a **spending limit ON** by default: if your credit ever runs out,
  resources are **turned off, not billed**.
- **Do NOT "remove the spending limit," and do NOT add a payment method.** As long as you don't,
  there's no way to run up a real charge.
- *(Optional peace of mind: Portal → Cost Management → Budgets → set a $5 alert.)*

## 3. Part 3 is built to stay free
- The required deploy runs on **Azure Container Apps**, which has a **monthly always-free grant**
  and **scales to zero** when idle — so it costs about nothing.
- **Just run the provided `deploy_azure.sh`.** It already uses the free-friendly settings
  (small container, scale-to-zero, one resource group) — you don't need to tune anything.
- Work in **Azure Cloud Shell** (in the portal, click the `>_` icon) — it's free, already signed
  in, and needs no local install. **Use Cloud Shell** — signing the Azure CLI in on a personal/
  campus-managed laptop may be blocked by university policy (error 53003); Cloud Shell avoids that.
- **Pick your student subscription first.** Cloud Shell may default to a university subscription
  where you can't create resources (you'll see `AuthorizationFailed`). Before deploying, run:
  ```
  az account set --subscription "Azure for Students"
  ```
- Heads-up: your **first** deploy may pause a few minutes while Azure "registers resource
  providers." That's normal — let it finish.

## 4. Everything lands in ONE resource group — so cleanup is one action
- The script puts all your Azure resources in a **single resource group** (`rg-data789-hw4-…`).
  That's the trick to painless teardown.
- **Tear it down the same day** you capture your screenshots:
  - **Command line:** `./teardown_azure.sh`  (or `az group delete -n <your-rg> --yes`)
  - **Portal:** **Resource groups** → click your `rg-data789-hw4-…` group → **Delete resource
    group** → type the name to confirm.
- Deleting the resource group removes **everything inside it** in one shot.

## 5. Confirm you're clean
- Portal → **Cost Management → Cost analysis** — your spend should be ~$0.
- Portal → **Resource groups** — after teardown, your HW4 group should be gone.

## Bonus (AKS) only
The optional AKS bonus uses a small VM node that **does** cost a little while it runs — do it in
one sitting and delete its resource group the same day. Azure for Students has a low vCPU quota,
so if the node won't create, that's expected — the bonus is optional, the Container Apps deploy
is what's required.

## Stuck?
- Verification problems → Azure for Students support, or ask the instructor.
- `AlreadyInUse` on the registry name → someone else already owns that globally-unique ACR name.
  `deploy_azure.sh` now detects this and appends a short random suffix automatically (it prints the new name).
- "Quota exceeded" on the bonus → expected; skip AKS. The Container Apps deploy is the required part.
