// SPDX-License-Identifier: Apache-2.0
// Copyright 2024 Authors of KubeArmor

package container_bpflsm

import (
	"os"
	"time"

	. "github.com/kubearmor/KubeArmor/tests/util"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = BeforeSuite(func() {
	// install wordpress-mysql deployment
	_, err := RunDockerCommand("compose -f res/wordpress_docker/compose.yaml up -d")
	Expect(err).To(BeNil())

	time.Sleep(2 * time.Second)
})

var _ = AfterSuite(func() {
	// delete wordpress-mysql app
	_, err := RunDockerCommand("rm -f wordpress-mysql")
	Expect(err).To(BeNil())

	time.Sleep(2 * time.Second)
})

var _ = Describe("Non-k8s container tests - BPFLSM", func() {

	BeforeEach(func() {
		// Set the environment variable
		os.Setenv("KUBEARMOR_SERVICE", ":32767")
	})

	AfterEach(func() {
		KarmorLogStop()
	})

	Describe("Process block", func() {
		It("can block execution of pkg mgmt tools such as apt, apt-get", func() {

			policyPath := "res/ksp-wordpress-block-process.yaml"
			err := SendPolicy("ADDED", policyPath)
			Expect(err).To(BeNil())

			// Start the karmor logs
			err = KarmorLogStart("policy", "", "Process", "")
			Expect(err).To(BeNil())
			time.Sleep(2 * time.Second)

			out, err := RunDockerCommand("exec wordpress-mysql apt")
			Expect(err).NotTo(BeNil())
			Expect(out).To(MatchRegexp(".*permission denied"))

			// check policy violation alert
			_, alerts, err := KarmorGetLogs(5*time.Second, 1)
			Expect(err).To(BeNil())
			Expect(len(alerts)).To(BeNumerically(">=", 1))
			Expect(alerts[0].PolicyName).To(Equal("ksp-wordpress-block-process"))
			Expect(alerts[0].Severity).To(Equal("3"))
			Expect(alerts[0].Action).To(Equal("Block"))

			err = SendPolicy("DELETED", policyPath)
			Expect(err).To(BeNil())
		})
	})

	Describe("UDP network block", func() {
		It("can block udp network in container", func() {

			policyPath := "res/ksp-wordpress-block-network.yaml"
			err := SendPolicy("ADDED", policyPath)
			Expect(err).To(BeNil())

			// Start the karmor logs
			err = KarmorLogStart("policy", "", "Network", "")
			Expect(err).To(BeNil())
			time.Sleep(2 * time.Second)

			// dns resolution of google.com requires udp, hence it should fail
			out, err := RunDockerCommand("exec wordpress-mysql curl google.com")
			Expect(err).NotTo(BeNil())
			Expect(out).To(MatchRegexp(".*Could not resolve host: google.com"))

			// curl on the ip is tcp and should work
			out, err = RunDockerCommand("exec wordpress-mysql curl 142.250.193.46")
			Expect(err).To(BeNil())
			Expect(out).NotTo(MatchRegexp(".*Could not resolve host: google.com"))

			// check policy violation alert
			_, alerts, err := KarmorGetLogs(5*time.Second, 1)
			Expect(err).To(BeNil())
			Expect(len(alerts)).To(BeNumerically(">=", 1))
			Expect(alerts[0].PolicyName).To(Equal("ksp-wordpress-block-network"))
			Expect(alerts[0].Severity).To(Equal("8"))
			Expect(alerts[0].Action).To(Equal("Block"))

			err = SendPolicy("DELETED", policyPath)
			Expect(err).To(BeNil())
		})
	})

	Describe("File access block from source", func() {
		It("can block access to configuration files", func() {

			policyPath := "res/ksp-wordpress-block-file-fromSource.yaml"
			err := SendPolicy("ADDED", policyPath)
			Expect(err).To(BeNil())

			// Start the karmor logs
			err = KarmorLogStart("policy", "", "File", "")
			Expect(err).To(BeNil())
			time.Sleep(2 * time.Second)

			// access to wp-config.php should be blocked from cat only
			out, err := RunDockerCommand("exec wordpress-mysql cat /var/www/html/wp-config.php")
			Expect(err).NotTo(BeNil())
			Expect(out).To(MatchRegexp(".*Permission denied"))

			// access to wp-config.php should be allowed from head
			out, err = RunDockerCommand("exec wordpress-mysql head /var/www/html/wp-config.php")
			Expect(err).To(BeNil())
			Expect(out).NotTo(MatchRegexp(".*Permission denied"))

			// check policy violation alert
			_, alerts, err := KarmorGetLogs(5*time.Second, 1)
			Expect(err).To(BeNil())
			Expect(len(alerts)).To(BeNumerically(">=", 1))
			Expect(alerts[0].PolicyName).To(Equal("ksp-wordpress-block-file-fromSource"))
			Expect(alerts[0].Severity).To(Equal("10"))
			Expect(alerts[0].Action).To(Equal("Block"))

			err = SendPolicy("DELETED", policyPath)
			Expect(err).To(BeNil())
		})
	})

	Describe("File Audit", func() {
		It("can audit access to files", func() {

			policyPath := "res/ksp-wordpress-audit-file.yaml"
			err := SendPolicy("ADDED", policyPath)
			Expect(err).To(BeNil())

			// Start the karmor logs
			err = KarmorLogStart("policy", "", "File", "")
			Expect(err).To(BeNil())
			time.Sleep(2 * time.Second)

			// access to /etc/passwd should be audited
			out, err := RunDockerCommand("exec wordpress-mysql cat /etc/passwd")
			Expect(err).To(BeNil())
			Expect(out).NotTo(MatchRegexp(".*permission denied"))

			// check policy violation alert
			_, alerts, err := KarmorGetLogs(5*time.Second, 1)
			Expect(err).To(BeNil())
			Expect(len(alerts)).To(BeNumerically(">=", 1))
			Expect(alerts[0].PolicyName).To(Equal("ksp-wordpress-audit-file"))
			Expect(alerts[0].Severity).To(Equal("6"))
			Expect(alerts[0].Action).To(Equal("Audit"))

			err = SendPolicy("DELETED", policyPath)
			Expect(err).To(BeNil())
		})
	})
})
