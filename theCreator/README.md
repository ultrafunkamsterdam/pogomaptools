This script helps in mass creation of pogo ptc accounts.

requirements: Linux, tor, 2captcha api-key, java runtime

```sudo apt-get -y update && sudo apt-get -y install tor && sudo apt-get install -y default-jre```

in config.properties -> put your 2captcha API-Key between the square backets

The script needs 5 arguments.

# example:
```./create.sh 12000 12800 MyAccount mycatchalldomain.com 50 ```
# please note: creation is done in groups of 100. After that it will create a new csv and create new proxies and start the next 100, until
your end number is reached. Make sure you choose numbers that can be divided by 100. Leftovers are NOT created)

The above script will create 800 accounts using 50 proxies per 100 accounts in about 5 minutes depending on your hardware and 2captcha rate, starting from MyAccount12000 until MyAccount12800 (800 accounts) and each activation mail is sent to its own names emailadress so MyAccount12000@mycatchalldomain.com until MyAccount12800@mycatchalldomain.com.