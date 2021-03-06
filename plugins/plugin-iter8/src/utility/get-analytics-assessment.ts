/*
 * Copyright 2020 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;
const path = require('path')

export default class GetAnalyticsAssessment {
  public data = {}
  public url = ''
  public constructor(data) {
    this.url = ''
    // If Iter8 Analytics URL is not defined as an Environment Variable- Use default
    if (process.env.ITER8_ANALYTICS_URL === undefined) {
      console.log('URL not defined')
      this.url = 'http://0.0.0.0:8080/assessment'
      console.log(this.url)
    }
    // If Iter8 Analytics URL is defined as an Environment Variable
    else {
      console.log('URL defined')
      this.url = path.join(process.env.ITER8_ANALYTICS_URL, 'assessment')
      console.log(this.url)
    }
    this.data = data
  }

  // AJAX Call to Iter8 and returns a promise
  public getAnalyticsAssessment() {
    const data = this.data
    const url = this.url
    const promiseObj = new Promise<string>(function(resolve, reject) {
      const xhr = new XMLHttpRequest()
      xhr.open('POST', url, true)
      xhr.setRequestHeader('Content-Type', 'application/json')
      xhr.send(JSON.stringify(data))
      xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
          if (xhr.status === 200) {
            console.log('Request processed successfully')
            const resp = xhr.responseText
            const respJson = JSON.stringify(resp)
            resolve(respJson)
          } else {
            reject(xhr.status)
            console.log('Request failed')
          }
        } else {
          console.log('Request processing going on')
        }
      }
      console.log('Request sent succesfully')
    })
    return promiseObj
  }
}
