# CreatorFund

**CreatorFund** is a decentralized application (DApp) smart contract built for the Stacks blockchain, enabling milestone-based crowdfunding for content creators. Fans can support creators by contributing STX tokens to creator projects before a deadline. Funds are only released if the funding goal is met.

---

## 🚀 Features

- Launch creator-led fundraising projects
- Fans can support projects with STX tokens
- Projects finalize funding status after the deadline
- Successful projects allow creators to withdraw funds
- Abandoned projects enable supporters to claim refunds
- Transparent supporter tracking and project metadata

---

## 📦 Data Structures

### `creator-projects` (map)
Stores project metadata:
- `creator`: Project owner
- `project-name`: Name of the project
- `content-description`: Description of the creative work
- `funding-target`: Goal in STX
- `support-deadline`: Block height deadline
- `total-support`: Current support total
- `status`: Project status (seeking, funded, abandoned)
- `launched-at`: Block when project was created

### `fan-support` (map)
Tracks STX contributions per project and supporter.

### `project-supporters` (map)
Lists unique supporters for each project (up to 200).

---

## ⚙️ Public Functions

### `launch-creator-project`
Creates a new project.
```lisp
(launch-creator-project (project-name string) (content-description string) (funding-target uint) (support-period uint))
