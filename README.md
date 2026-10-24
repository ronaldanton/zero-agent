# ZeroAgent

Hermes Agent core + a powerhouse overlay: security/defense/offense working config, hourly self-learning cron, and a one-line installer.

```bash
curl -fsSL https://raw.githubusercontent.com/ronaldanton/zero-agent/main/install.sh | bash
```

- Installs Hermes Agent (Nous Research) as the core engine
- Creates the `zero` profile
- Installs the `zero-powerhouse` skill pack
- Adds the `zero-learn` hourly cron (session review → durable lesson → skill update)

Run it: `hermes -p zero`

Core link: https://github.com/NousResearch/hermes-agent
