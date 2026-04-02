# DNS Configuration for Final Evolution Lab
# Server IP: 198.212.42.22

| Type  | Name                              | Value          | TTL  |
|-------|-----------------------------------|----------------|------|
| A     | finalevolutiongroup.com           | 198.212.42.22     | 300  |
| A     | www.finalevolutiongroup.com       | 198.212.42.22     | 300  |
| A     | app.finalevolutiongroup.com       | 198.212.42.22     | 300  |
| A     | stream.finalevolutiongroup.com    | 198.212.42.22     | 300  |
| A     | api.finalevolutiongroup.com       | 198.212.42.22     | 300  |
| A     | admin.finalevolutiongroup.com     | 198.212.42.22     | 300  |

## SSL Setup (after DNS propagation):
```bash
sudo certbot --nginx -d finalevolutiongroup.com -d www.finalevolutiongroup.com \
  -d app.finalevolutiongroup.com -d stream.finalevolutiongroup.com \
  -d api.finalevolutiongroup.com
```
