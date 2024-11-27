#!/bin/bash

# AWS credentials ve region'ın ayarlandığını varsayıyoruz
# Değilse, aşağıdaki gibi ayarlanabilir:
# export AWS_PROFILE=your-profile
# export AWS_REGION=your-region

# Renkli output için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 S3 ve EFS Çoklu AZ/Region Kontrol Scripti"
echo "----------------------------------------"

# S3 Bucket Kontrolü
check_s3_buckets() {
    echo -e "\n📦 S3 Bucket Kontrolleri:"
    buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
    
    for bucket in $buckets; do
        echo -e "\nBucket: ${YELLOW}$bucket${NC}"
        
        # Versiyonlama kontrolü
        versioning=$(aws s3api get-bucket-versioning --bucket $bucket --query 'Status' --output text 2>/dev/null)
        echo -e "Versiyonlama: ${versioning:-Disabled}"
        
        # Replikasyon kontrolü
        replication=$(aws s3api get-bucket-replication --bucket $bucket 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "Replikasyon: ${GREEN}Aktif${NC}"
            # Replikasyon hedef bölgesini göster
            dest_region=$(echo $replication | jq -r '.ReplicationConfiguration.Rules[0].Destination.Bucket' 2>/dev/null)
            echo "Hedef Region: $dest_region"
        else
            echo -e "Replikasyon: ${RED}Pasif${NC}"
        fi
        
        # Bucket lokasyonu
        location=$(aws s3api get-bucket-location --bucket $bucket --query 'LocationConstraint' --output text)
        echo "Lokasyon: ${location:-us-east-1}"
    done
}

# EFS Kontrolü
check_efs_systems() {
    echo -e "\n📁 EFS Sistemleri Kontrolü:"
    
    # Tüm EFS sistemlerini listele
    efs_systems=$(aws efs describe-file-systems --query 'FileSystems[*].FileSystemId' --output text)
    
    for efs_id in $efs_systems; do
        echo -e "\nEFS ID: ${YELLOW}$efs_id${NC}"
        
        # Mount noktalarını kontrol et
        mount_targets=$(aws efs describe-mount-targets --file-system-id $efs_id)
        mount_count=$(echo $mount_targets | jq '.MountTargets | length')
        
        # Mount noktalarının AZ'lerini listele
        azs=$(echo $mount_targets | jq -r '.MountTargets[].AvailabilityZoneName' | sort)
        
        echo "Mount Hedef Sayısı: $mount_count"
        echo "Availability Zones:"
        echo "$azs" | while read az; do
            echo "- $az"
        done
        
        # Multi-AZ durumunu değerlendir
        if [ $mount_count -gt 1 ]; then
            echo -e "Multi-AZ Durumu: ${GREEN}Aktif${NC}"
        else
            echo -e "Multi-AZ Durumu: ${RED}Pasif${NC}"
        fi
        
        # Performans modu
        perf_mode=$(aws efs describe-file-systems --file-system-id $efs_id --query 'FileSystems[0].PerformanceMode' --output text)
        echo "Performans Modu: $perf_mode"
    done
}

# Ana fonksiyonları çalıştır
main() {
    check_s3_buckets
    check_efs_systems
}

# Script'i çalıştır
main
