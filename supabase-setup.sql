-- ================================================
-- SOMUN UN — SUPABASE TABLO YAPISI
-- Bu SQL'i Supabase Dashboard > SQL Editor'de çalıştırın
-- ================================================

-- 1. Kullanıcı Profilleri
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  gender TEXT DEFAULT 'Bey',
  newsletter BOOLEAN DEFAULT true,
  kvkk BOOLEAN DEFAULT true,
  terms BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Adresler
CREATE TABLE IF NOT EXISTS addresses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL DEFAULT 'Ev',
  full_name TEXT,
  phone TEXT,
  city TEXT,
  district TEXT,
  address_line TEXT NOT NULL,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Siparişler
CREATE TABLE IF NOT EXISTS orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  order_no TEXT NOT NULL,
  items JSONB NOT NULL,
  total NUMERIC NOT NULL,
  status TEXT DEFAULT 'pending',
  shipping_address JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Stok Bildirim İstekleri
CREATE TABLE IF NOT EXISTS stock_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id INTEGER NOT NULL,
  product_name TEXT NOT NULL,
  email TEXT NOT NULL,
  notified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Row Level Security (RLS) Politikaları
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_notifications ENABLE ROW LEVEL SECURITY;

-- Profiller: Kendi profilini okuma/güncelleme
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Adresler: Kendi adreslerini CRUD
CREATE POLICY "Users can manage own addresses" ON addresses FOR ALL USING (auth.uid() = user_id);

-- Siparişler: Kendi siparişlerini okuma/oluşturma
CREATE POLICY "Users can view own orders" ON orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create orders" ON orders FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Stok bildirimleri: Kendi bildirimlerini CRUD
CREATE POLICY "Users can manage own stock notifications" ON stock_notifications FOR ALL USING (auth.uid() = user_id);

-- 6. Profil otomatik oluşturma fonksiyonu
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, phone, gender, newsletter)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'Bey'),
    COALESCE((NEW.raw_user_meta_data->>'newsletter')::boolean, true)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Yeni kullanıcı kaydında profil oluştur
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
