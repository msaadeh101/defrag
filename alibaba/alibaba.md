# Alibaba Cloud


## Example Project

- Set Credentials in Github or Jenkins

- Run the Swiss Army Knife:

```bash
# Configure and deploy
./general-swiss-army.sh config
./general-swiss-army.sh deploy

# Monitor deployed resources
./general-swiss-army.sh health-check
```

- User_data script sets up the ECS instance:

It runs again upon changes to the script due to `lifecycle`
