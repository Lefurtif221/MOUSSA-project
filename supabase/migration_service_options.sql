-- Variantes de prix, suppléments, supplément domicile
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS variantes jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS supplements jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS supplement_domicile integer DEFAULT 0;
