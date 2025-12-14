# Inception-of-Things (IoT)

Bu proje, Kubernetes kümelerini (clusters) kurma, yönetme ve Sürekli Entegrasyon (CI/CD) mekanizmalarını anlama üzerine odaklanan bir Sistem Yönetimi alıştırmasıdır. Proje kapsamında **K3s**, **K3d**, **Vagrant**, **Docker** ve **Argo CD** teknolojileri kullanılmaktadır.

## 📚 Proje İçeriği

Proje üç zorunlu bölüm ve bir bonus bölümden oluşmaktadır:

  * **Part 1 (p1):** Vagrant ve K3s ile iki sanal makine (Server & Worker) kurulumu.
  * **Part 2 (p2):** K3s, Ingress ve üç basit web uygulamasının tek bir VM üzerinde orkestrasyonu.
  * **Part 3 (p3):** K3d ve Argo CD kullanarak tamamen Docker üzerinde çalışan bir CI/CD pipeline'ı oluşturma.

## 🛠 Gereksinimler

Bu projeyi çalıştırmak için aşağıdaki araçların bilgisayarınızda yüklü olması gerekmektedir:

  * **VirtualBox** (Part 1 & 2 için)
  * **Vagrant** (Part 1 & 2 için)
  * **Docker** (Part 3 için)
  * **K3d** (Part 3 için)
  * **kubectl** (Kümeleri yönetmek için)

-----

## 📂 Part 1: K3s ve Vagrant

Bu bölümde, Vagrant kullanılarak iki sanal makine ayağa kaldırılır ve K3s ile bir Kubernetes kümesi oluşturulur.

  * **Server (Master):** `192.168.56.110`
  * **Server Worker (Agent):** `192.168.56.111`

### Kurulum ve Çalıştırma

1.  `p1` dizinine gidin:
    ```bash
    cd p1
    ```
2.  Sanal makineleri başlatın:
    ```bash
    vagrant up
    ```
3.  Makineler ayağa kalktıktan sonra Server makinesine bağlanarak node'ların durumunu kontrol edebilirsiniz:
    ```bash
    vagrant ssh <kullanici_adi>S  # Örn: batuhantanirS
    kubectl get nodes -o wide
    ```

-----

## 📂 Part 2: K3s ve Üç Basit Uygulama

Bu bölümde tek bir sanal makine (`192.168.56.110`) üzerinde K3s sunucusu çalıştırılır. Ingress kullanılarak trafiğin ilgili uygulamalara (app1, app2, app3) yönlendirilmesi sağlanır.

### Kurulum ve Çalıştırma

1.  `p2` dizinine gidin:
    ```bash
    cd p2
    ```
2.  Sanal makineyi başlatın:
    ```bash
    vagrant up
    ```
3.  **Host Dosyası Ayarı:**
    Uygulamalara erişebilmek için kendi bilgisayarınızın (host) `/etc/hosts` dosyasına aşağıdaki satırı eklemelisiniz:
    ```text
    192.168.56.110 app1.com app2.com app3.com
    ```
4.  **Test:**
    Tarayıcınızdan veya terminalden uygulamaları test edebilirsiniz:
    ```bash
    curl -H "Host: app1.com" 192.168.56.110
    curl -H "Host: app2.com" 192.168.56.110
    ```

-----

## 📂 Part 3: K3d ve Argo CD

Bu bölümde Vagrant kullanılmaz. Bunun yerine K3d kullanılarak Docker üzerinde çalışan bir Kubernetes kümesi oluşturulur. Argo CD kurularak, bir GitHub deposundaki değişikliklerin otomatik olarak uygulamaya (sync) yansıması sağlanır.

### Yapı

  * **Namespaces:** `argocd`, `dev`
  * **Repository:** Uygulama konfigürasyonlarını içeren GitHub deposu Argo CD'ye bağlanır.

### Kurulum ve Çalıştırma

1.  `p3` dizinine gidin:

    ```bash
    cd p3
    ```

2.  Kurulum scriptini çalıştırın (Script ismi projenizdeki dosyaya göre değişebilir, genellikle `install.sh` veya `setup.sh`):

    ```bash
    ./scripts/install.sh
    ```

3.  **Argo CD Arayüzüne Erişim:**
    Port yönlendirme (port-forward) işlemi yapıldıktan sonra tarayıcıdan Argo CD arayüzüne erişebilirsiniz:

      * URL: `http://localhost:8080` (Varsayılan port yapılandırmanıza göre değişebilir)
      * Kullanıcı adı: `admin`
      * Şifre: (Script çıktısında veya secret içerisinde belirtilen şifre)

4.  **Uygulama Güncelleme Testi:**
    Bağlı olan GitHub reposundaki `deployment.yaml` dosyasında imaj sürümünü (örneğin `v1`'den `v2`'ye) güncelleyip pushladığınızda, Argo CD'nin bu değişikliği algılayıp `dev` namespace'indeki podları güncellediğini görebilirsiniz.

## ⚠️ Önemli Notlar

  * Vagrant makinelerini kapatmak için ilgili dizinde `vagrant halt`, tamamen silmek için `vagrant destroy` komutlarını kullanabilirsiniz.
  * Part 3 kısımı Docker üzerinde çalıştığı için Docker Desktop veya Docker Engine'in açık olduğundan emin olun.
  * Projeyi değerlendirirken veya sunarken `kubectl` ve `k3d` komutlarının çıktılarını göstermeniz beklenebilir.
