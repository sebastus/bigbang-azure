kill-kubens.sh bigbang 
kill-kubens.sh eck-operator
kill-kubens.sh gatekeeper-system
kill-kubens.sh istio-operator
kill-kubens.sh istio-system
kill-kubens.sh jaeger
kill-kubens.sh kiali
kill-kubens.sh logging
kill-kubens.sh monitoring
kill-kubens.sh twistlock

kubectl delete ValidatingWebhookConfiguration gatekeeper-validating-webhook-configuration
