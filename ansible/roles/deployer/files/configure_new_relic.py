#!/usr/bin/env python
import urllib
import urllib2
import json
import sys
import fileinput

if len(sys.argv) < 4:
    print "Usage: %s NEW_RELIC_API_KEY NEW_RELIC_POLICY_ID FILE" % (sys.argv[0])
    sys.exit(1)
new_relic_api_key = sys.argv[1]
alert_policy_id = int(sys.argv[2])
config = None
with open(sys.argv[3]) as data_file:
    config = json.load(data_file)

def get_data(url, data):
    data = urllib.urlencode(data)
    headers = {'X-Api-Key': new_relic_api_key}
    req = urllib2.Request(url, data, headers)
    response = urllib2.urlopen(req)
    return json.load(response)

def post_data(url, data):
    request = urllib2.Request(url)
    request.add_header('X-Api-Key', new_relic_api_key)
    request.add_header('Content-Type', 'application/json')
    response = urllib2.urlopen(request, json.dumps(data))
    return

def put_data(url, data):
    request = urllib2.Request(url)
    request.add_header('X-Api-Key', new_relic_api_key)
    request.add_header('Content-Type', 'application/json')
    request.get_method = lambda: 'PUT'
    response = urllib2.urlopen(request, json.dumps(data))
    return

def get_servers(labels):
    output_servers = None
    for label in labels:
        response_json = get_data('https://api.newrelic.com/v2/servers.json', {'filter[labels]': label})
        if output_servers is None:
            output_servers = response_json['servers']
        else:
            result = []
            for output_server in output_servers:
                contains = False
                for server in response_json['servers']:
                    if output_server['id'] == server['id']:
                        contains = True
                if contains:
                    result.append(output_server)
            output_servers = result
    return output_servers

def get_alert_conditions(policy_id):
    return get_data('https://api.newrelic.com/v2/alerts_conditions.json', {'policy_id': policy_id})['conditions']

def create_or_update_alert_condition(policy_id, current_alert_conditions, name, entities, metric, conditions, cluster_name):
    condition_name = "[AUTO][%s] %s" % (cluster_name, name)
    entities_ids = []
    for entity in entities:
        entities_ids.append(entity['id'])
    create = True
    condition = None
    for alert_condition in current_alert_conditions:
        if alert_condition['name'] == condition_name:
            create = False
            condition = alert_condition
    if condition is None:
        condition = {
            "type": "servers_metric",
            "name": condition_name,
            "enabled": True,
            "entities": [],
            "metric": metric,
            "terms": []
        }
    condition["entities"] = entities_ids
    condition["terms"] = conditions
    if create:
        print "Creating %s" % condition_name
        post_data("https://api.newrelic.com/v2/alerts_conditions/policies/%d.json" % (policy_id), {"condition": condition})
    else:
        print "Updating %s" % condition_name
        put_data("https://api.newrelic.com/v2/alerts_conditions/%d.json" % (condition['id']), {"condition": condition})
    return

current_alert_conditions = get_alert_conditions(alert_policy_id)

for group in config:
    servers = get_servers(group['labels'])
    for condition in group['conditions']:
        create_or_update_alert_condition(alert_policy_id, current_alert_conditions, condition['name'], servers, condition['metric'], condition['terms'], group['environment'])
